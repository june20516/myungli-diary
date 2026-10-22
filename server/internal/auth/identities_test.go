package auth_test

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/auth"
	"github.com/june20516/myungli-diary/server/internal/auth/provider"
	"github.com/june20516/myungli-diary/server/internal/auth/provider/providertest"
)

// lineProof는 subject로 검증을 통과하는 LINE 붙이기 증명입니다.
func (f *fixture) lineProof(subject string) auth.LinkProof {
	return auth.LinkProof{IDToken: f.fake.SignES256IDToken(providertest.LINEClaims(subject, testNonce, f.clk.Now())), RawNonce: testNonce}
}

// appleProof는 subject로 검증과 code 교환을 통과하는 Apple iOS 붙이기 증명입니다.
func (f *fixture) appleProof(subject string) auth.LinkProof {
	return auth.LinkProof{
		IDToken:           f.fake.SignIDToken(providertest.AppleClaims(subject, testNonce, provider.AppleNative, f.clk.Now())),
		AuthorizationCode: providertest.AppleCode(subject),
		RawNonce:          testNonce,
	}
}

// link는 계정에 연결을 붙이고 성공을 확인합니다.
func (f *fixture) link(t *testing.T, accountID uuid.UUID, prov string, proof auth.LinkProof) auth.LinkResult {
	t.Helper()
	res, err := f.service.LinkIdentity(f.ctx, accountID, prov, proof)
	require.NoError(t, err)
	return res
}

// providers는 ListIdentities가 돌려준 제공자 이름을 순서대로 돌려줍니다.
func (f *fixture) providers(t *testing.T, accountID uuid.UUID) []string {
	t.Helper()
	identities, err := f.service.ListIdentities(f.ctx, accountID)
	require.NoError(t, err)
	names := make([]string, 0, len(identities))
	for _, identity := range identities {
		names = append(names, identity.Provider)
	}
	return names
}

// appleRefreshOf는 계정의 Apple 연결에 저장한 refresh token을 복호화해 돌려줍니다.
func (f *fixture) appleRefreshOf(t *testing.T, accountID uuid.UUID) string {
	t.Helper()
	var (
		id     uuid.UUID
		sealed []byte
		keyID  string
	)
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT id, apple_refresh_token, apple_token_key_id FROM auth_identities WHERE account_id = $1 AND provider = 'apple'`,
		accountID).Scan(&id, &sealed, &keyID))
	plain, err := f.box.Open(sealed, keyID, id[:])
	require.NoError(t, err)
	return string(plain)
}

// newAccount는 연결 없는 active 계정 행을 만듭니다. 제공자 호출 없이 계정이 필요할 때 씁니다.
func (f *fixture) newAccount(t *testing.T) uuid.UUID {
	t.Helper()
	accountID := uuid.Must(uuid.NewV7())
	f.exec(t, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', $2)`, accountID, f.clk.Now())
	return accountID
}

func TestLinkIdentity_CreatesWhenFree(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginKakao(t, "kakao-1").AccountID

	res := f.link(t, accountID, "line", f.lineProof("U1"))

	assert.True(t, res.Created)
	assert.Equal(t, []string{"kakao", "line"}, f.providers(t, accountID), "붙인 순입니다")
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE account_id = $1 AND provider = 'line' AND subject = 'U1'`, accountID))
	identities, err := f.service.ListIdentities(f.ctx, accountID)
	require.NoError(t, err)
	for _, identity := range identities {
		assert.False(t, identity.LinkedAt.IsZero(), identity.Provider)
	}
}

func TestLinkIdentity_IsIdempotentForOwnIdentity(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginKakao(t, "kakao-1").AccountID
	f.link(t, accountID, "line", f.lineProof("U1"))

	again := f.link(t, accountID, "line", f.lineProof("U1"))

	assert.False(t, again.Created)
	assert.Equal(t, 2, f.count(t, `SELECT count(*) FROM auth_identities WHERE account_id = $1`, accountID))

	// Apple은 같은 연결을 다시 붙이면 refresh token만 새 값으로 바꿉니다.
	assert.True(t, f.link(t, accountID, "apple", f.appleProof("A1")).Created)
	assert.Equal(t, providertest.AppleRefreshToken, f.appleRefreshOf(t, accountID))
	f.fake.SetAppleRefreshToken("second-refresh")

	appleAgain := f.link(t, accountID, "apple", f.appleProof("A1"))

	assert.False(t, appleAgain.Created)
	assert.Equal(t, "second-refresh", f.appleRefreshOf(t, accountID))
	assert.Equal(t, 3, f.count(t, `SELECT count(*) FROM auth_identities WHERE account_id = $1`, accountID))
	assert.Empty(t, f.fake.AppleRevokeRequests())
}

func TestLinkIdentity_ProviderTaken(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginLine(t, "U1").AccountID

	_, err := f.service.LinkIdentity(f.ctx, accountID, "line", f.lineProof("U2"))

	require.ErrorIs(t, err, auth.ErrProviderTaken)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities`))
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
}

func TestLinkIdentity_InUseIssuesMergeTicket(t *testing.T) {
	f := newFixture(t)
	other := f.loginLine(t, "U1").AccountID
	me := f.loginKakao(t, "kakao-1").AccountID
	// 나노초가 있는 시각으로 만료 시각의 마이크로초 절사를 확인합니다.
	f.clk.Advance(1234 * time.Nanosecond)
	now := f.clk.Now()

	_, err := f.service.LinkIdentity(f.ctx, me, "line", f.lineProof("U1"))

	var inUse *auth.IdentityInUseError
	require.ErrorAs(t, err, &inUse)
	assert.Len(t, inUse.MergeToken, 43, "32바이트 난수의 base64url(패딩 없음)은 43자입니다")
	raw, decodeErr := base64.RawURLEncoding.DecodeString(inUse.MergeToken)
	require.NoError(t, decodeErr)
	assert.Len(t, raw, 32)
	assert.Equal(t, now.Add(auth.MergeTicketTTL).Truncate(time.Microsecond), inUse.ExpiresAt)
	assert.NotContains(t, err.Error(), inUse.MergeToken, "오류 문구에 토큰을 넣지 않습니다")

	var (
		accountID, otherAccountID, identityID uuid.UUID
		expiresAt                             time.Time
		consumedAt                            *time.Time
	)
	hash := sha256.Sum256([]byte(inUse.MergeToken))
	require.NoError(t, f.pool.QueryRow(f.ctx,
		`SELECT account_id, other_account_id, identity_id, expires_at, consumed_at FROM account_merge_tickets WHERE token_hash = $1`,
		hash[:]).Scan(&accountID, &otherAccountID, &identityID, &expiresAt, &consumedAt))
	assert.Equal(t, me, accountID, "토큰을 쓸 수 있는 쪽은 현재 계정입니다")
	assert.Equal(t, other, otherAccountID)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE id = $1 AND account_id = $2 AND provider = 'line'`, identityID, other))
	assert.True(t, expiresAt.Equal(inUse.ExpiresAt))
	assert.Nil(t, consumedAt)

	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
	assert.Equal(t, 0, f.count(t,
		`SELECT count(*) FROM account_merge_tickets WHERE position(convert_to($1, 'UTF8') IN token_hash) > 0`,
		inUse.MergeToken), "원문은 저장하지 않습니다")
	assert.Equal(t, []string{"kakao"}, f.providers(t, me), "연결은 옮기지 않습니다")
}

func TestLinkIdentity_InUseDiscardsNewAppleGrantWithoutRevoke(t *testing.T) {
	f := newFixture(t)
	other := f.loginApple(t, "A1").AccountID
	me := f.loginKakao(t, "kakao-1").AccountID
	f.fake.SetAppleRefreshToken("new-refresh")

	_, err := f.service.LinkIdentity(f.ctx, me, "apple", f.appleProof("A1"))

	var inUse *auth.IdentityInUseError
	require.ErrorAs(t, err, &inUse)
	assert.Empty(t, f.fake.AppleRevokeRequests(), "revoke하면 다른 계정에 저장된 연결까지 무효가 됩니다")
	assert.Equal(t, providertest.AppleRefreshToken, f.appleRefreshOf(t, other), "다른 계정의 토큰은 그대로입니다")
}

func TestLinkIdentity_PendingDeletionOwner(t *testing.T) {
	f := newFixture(t)
	other := f.loginLine(t, "U1").AccountID
	f.markPendingDeletion(t, other)
	me := f.loginKakao(t, "kakao-1").AccountID

	_, err := f.service.LinkIdentity(f.ctx, me, "line", f.lineProof("U1"))

	require.ErrorIs(t, err, auth.ErrIdentityPendingDeletion)
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
	assert.Equal(t, []string{"kakao"}, f.providers(t, me))
}

// Review Focus 1: 같은 연결을 두 계정이 동시에 붙이면 한쪽만 붙이고 다른 쪽은 합치기 토큰을 받습니다.
func TestLinkIdentity_ConcurrentLinkOfSameIdentity(t *testing.T) {
	f := newFixture(t)
	accounts := []uuid.UUID{f.loginKakao(t, "kakao-1").AccountID, f.loginKakao(t, "kakao-2").AccountID}
	proofs := make([]auth.LinkProof, len(accounts))
	for i := range proofs {
		proofs[i] = auth.LinkProof{IDToken: f.googleToken("G1"), RawNonce: testNonce}
	}

	results := make([]auth.LinkResult, len(accounts))
	errs := make([]error, len(accounts))
	startTogether(len(accounts), func(i int) {
		results[i], errs[i] = f.service.LinkIdentity(f.ctx, accounts[i], "google", proofs[i])
	})

	created, inUse := 0, 0
	for i, err := range errs {
		var inUseErr *auth.IdentityInUseError
		switch {
		case err == nil:
			assert.True(t, results[i].Created)
			created++
		case errors.As(err, &inUseErr):
			inUse++
		default:
			t.Fatalf("예상하지 못한 오류: %v", err)
		}
	}
	assert.Equal(t, 1, created)
	assert.Equal(t, 1, inUse)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE provider = 'google'`))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM account_merge_tickets`))
}

// 동시 붙이기의 unique 위반 재시도 경로를 결정적으로 재현합니다.
// 다른 트랜잭션이 같은 (provider, subject)를 넣고 commit하지 않은 채로 있으면, 붙이기는 identity insert에서 기다리다
// 그 트랜잭션이 commit되면 unique 위반을 받고, 처음부터 다시 실행해 합치기 토큰을 받습니다.
func TestLinkIdentity_UniqueConflictRetriesAsInUse(t *testing.T) {
	f := newFixture(t)
	me := f.loginKakao(t, "kakao-1").AccountID
	other := uuid.Must(uuid.NewV7())
	tx, err := f.pool.Begin(f.ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = tx.Rollback(context.Background()) })
	_, err = tx.Exec(f.ctx, `INSERT INTO accounts (id, status, last_active_at) VALUES ($1, 'active', $2)`, other, testNow)
	require.NoError(t, err)
	_, err = tx.Exec(f.ctx, `INSERT INTO auth_identities (id, account_id, provider, subject) VALUES ($1, $2, 'google', 'G1')`,
		uuid.Must(uuid.NewV7()), other)
	require.NoError(t, err)

	done := make(chan error, 1)
	proof := auth.LinkProof{IDToken: f.googleToken("G1"), RawNonce: testNonce}
	go func() {
		_, err := f.service.LinkIdentity(f.ctx, me, "google", proof)
		done <- err
	}()

	// 붙이기가 identity insert에서 잠금을 기다릴 때까지 기다린 뒤 다른 트랜잭션을 commit합니다.
	require.Eventually(t, func() bool {
		return f.count(t, `SELECT count(*) FROM pg_stat_activity
			WHERE datname = current_database() AND wait_event_type = 'Lock' AND query LIKE '%INSERT INTO auth_identities%'`) == 1
	}, 10*time.Second, 20*time.Millisecond)
	require.NoError(t, tx.Commit(f.ctx))

	err = <-done
	var inUse *auth.IdentityInUseError
	require.ErrorAs(t, err, &inUse)
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM account_merge_tickets WHERE account_id = $1 AND other_account_id = $2`, me, other))
	assert.Equal(t, []string{"kakao"}, f.providers(t, me), "실패한 첫 시도의 연결 행은 rollback됩니다")
}

func TestLinkIdentity_InvalidProofCombinations(t *testing.T) {
	f := newFixture(t)
	accountID := f.newAccount(t)
	jwksBefore := f.fake.JWKSHits()

	cases := []struct {
		name     string
		provider string
		proof    auth.LinkProof
		want     auth.InvalidProofError
	}{
		{"LINE에 idToken 없음", "line", auth.LinkProof{RawNonce: testNonce}, auth.InvalidProofError{Field: "/idToken", Code: "required"}},
		{"LINE에 authorizationCode 있음", "line", auth.LinkProof{IDToken: "t", AuthorizationCode: "c", RawNonce: testNonce},
			auth.InvalidProofError{Field: "/authorizationCode", Code: "additionalProperties"}},
		{"카카오에 exchangeCode 있음", "kakao", auth.LinkProof{IDToken: "t", ExchangeCode: "e", RawNonce: testNonce},
			auth.InvalidProofError{Field: "/exchangeCode", Code: "additionalProperties"}},
		{"Google에 nonce 없음", "google", auth.LinkProof{IDToken: "t"}, auth.InvalidProofError{Field: "/nonce", Code: "required"}},
		{"Apple에 idToken만", "apple", auth.LinkProof{IDToken: "t", RawNonce: testNonce},
			auth.InvalidProofError{Field: "/authorizationCode", Code: "required"}},
		{"Apple에 iOS 두 값과 exchangeCode", "apple", auth.LinkProof{IDToken: "t", AuthorizationCode: "c", ExchangeCode: "e", RawNonce: testNonce},
			auth.InvalidProofError{Field: "/exchangeCode", Code: "additionalProperties"}},
		{"Apple에 아무것도 없음", "apple", auth.LinkProof{RawNonce: testNonce}, auth.InvalidProofError{Field: "/idToken", Code: "required"}},
		{"Apple 웹에 nonce 없음", "apple", auth.LinkProof{ExchangeCode: "e"}, auth.InvalidProofError{Field: "/nonce", Code: "required"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := f.service.LinkIdentity(f.ctx, accountID, tc.provider, tc.proof)

			require.ErrorIs(t, err, auth.ErrInvalidProof)
			var invalid *auth.InvalidProofError
			require.ErrorAs(t, err, &invalid)
			assert.Equal(t, tc.want, *invalid)
		})
	}
	assert.Equal(t, jwksBefore, f.fake.JWKSHits(), "조합 검사는 제공자 호출 전에 합니다")
	assert.Empty(t, f.fake.AppleTokenRequests())
	assert.Equal(t, 0, f.count(t, `SELECT count(*) FROM auth_identities`))
}

func TestLinkIdentity_AppleWebExchangeCode(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginKakao(t, "kakao-1").AccountID
	code := f.beginAppleWeb(t, "A1")

	_, err := f.service.LinkIdentity(f.ctx, accountID, "apple", auth.LinkProof{ExchangeCode: code, RawNonce: "wrong-nonce"})

	require.ErrorIs(t, err, auth.ErrExchangeInvalid)
	assert.Nil(t, f.appleWebRow(t, code).consumedAt, "nonce가 틀려도 코드를 소진하지 않습니다")
	assert.Equal(t, []string{"kakao"}, f.providers(t, accountID))

	res := f.link(t, accountID, "apple", auth.LinkProof{ExchangeCode: code, RawNonce: testNonce})

	assert.True(t, res.Created)
	assert.NotNil(t, f.appleWebRow(t, code).consumedAt)
	assert.Equal(t, []string{"kakao", "apple"}, f.providers(t, accountID))
	assert.Equal(t, 1, f.count(t, `SELECT count(*) FROM auth_identities WHERE account_id = $1 AND provider = 'apple' AND subject = 'A1' AND apple_client_id = $2`,
		accountID, providertest.AppleServicesID))
	assert.Equal(t, providertest.AppleRefreshToken, f.appleRefreshOf(t, accountID))

	// 소진한 코드는 다시 쓸 수 없습니다.
	_, err = f.service.LinkIdentity(f.ctx, accountID, "apple", auth.LinkProof{ExchangeCode: code, RawNonce: testNonce})
	require.ErrorIs(t, err, auth.ErrExchangeInvalid)
}

func TestUnlinkIdentity_RemovesAndRevokesAfterCommit(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginKakao(t, "kakao-1").AccountID
	f.link(t, accountID, "apple", f.appleProof("A1"))

	require.NoError(t, f.service.UnlinkIdentity(f.ctx, accountID, "apple"))

	assert.Equal(t, []string{"kakao"}, f.providers(t, accountID))
	revokes := f.fake.AppleRevokeRequests()
	require.Len(t, revokes, 1)
	assert.Equal(t, providertest.AppleRefreshToken, revokes[0].Form.Get("token"), "복호화한 토큰으로 revoke합니다")
	assert.Equal(t, providertest.AppleBundleID, revokes[0].Form.Get("client_id"))

	// revoke가 실패해도 떼기는 성공입니다.
	f.link(t, accountID, "apple", f.appleProof("A1"))
	f.fake.SetAppleRevokeResponse(http.StatusServiceUnavailable, "")

	require.NoError(t, f.service.UnlinkIdentity(f.ctx, accountID, "apple"))

	assert.Equal(t, []string{"kakao"}, f.providers(t, accountID))
	assert.Len(t, f.fake.AppleRevokeRequests(), 2)
}

func TestUnlinkIdentity_KakaoUnlinksAfterCommit(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginLine(t, "U1").AccountID
	f.link(t, accountID, "kakao", auth.LinkProof{IDToken: f.kakaoToken("kakao-1"), RawNonce: testNonce})

	require.NoError(t, f.service.UnlinkIdentity(f.ctx, accountID, "kakao"))

	assert.Equal(t, []string{"line"}, f.providers(t, accountID))
	unlinks := f.fake.KakaoUnlinkRequests()
	require.Len(t, unlinks, 1)
	assert.Equal(t, "kakao-1", unlinks[0].Form.Get("target_id"))
}

func TestUnlinkIdentity_LINEGoogleNoExternalCall(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginKakao(t, "kakao-1").AccountID
	f.link(t, accountID, "line", f.lineProof("U1"))
	f.link(t, accountID, "google", auth.LinkProof{IDToken: f.googleToken("G1"), RawNonce: testNonce})

	require.NoError(t, f.service.UnlinkIdentity(f.ctx, accountID, "line"))
	require.NoError(t, f.service.UnlinkIdentity(f.ctx, accountID, "google"))

	assert.Equal(t, []string{"kakao"}, f.providers(t, accountID))
	assert.Empty(t, f.fake.AppleRevokeRequests())
	assert.Empty(t, f.fake.KakaoUnlinkRequests())
}

func TestUnlinkIdentity_LastAndMissing(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginKakao(t, "kakao-1").AccountID

	require.ErrorIs(t, f.service.UnlinkIdentity(f.ctx, accountID, "kakao"), auth.ErrLastIdentity)
	require.ErrorIs(t, f.service.UnlinkIdentity(f.ctx, accountID, "line"), auth.ErrIdentityNotFound)

	assert.Equal(t, []string{"kakao"}, f.providers(t, accountID))
	assert.Empty(t, f.fake.KakaoUnlinkRequests())
}

// 연결 둘을 동시에 떼면 계정 행 잠금으로 한 줄로 처리되어 하나는 남습니다.
func TestUnlinkIdentity_ConcurrentUnlinkKeepsOne(t *testing.T) {
	f := newFixture(t)
	accountID := f.loginKakao(t, "kakao-1").AccountID
	f.link(t, accountID, "line", f.lineProof("U1"))
	targets := []string{"kakao", "line"}

	errs := make([]error, len(targets))
	startTogether(len(targets), func(i int) {
		errs[i] = f.service.UnlinkIdentity(f.ctx, accountID, targets[i])
	})

	succeeded, last := 0, 0
	for _, err := range errs {
		switch {
		case err == nil:
			succeeded++
		case errors.Is(err, auth.ErrLastIdentity):
			last++
		default:
			t.Fatalf("예상하지 못한 오류: %v", err)
		}
	}
	assert.Equal(t, 1, succeeded)
	assert.Equal(t, 1, last)
	assert.Len(t, f.providers(t, accountID), 1)
}
