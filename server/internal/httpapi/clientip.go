package httpapi

import (
	"net"
	"net/http"
	"net/netip"
	"strings"
)

// ClientIP는 요청을 보낸 클라이언트의 IP를 돌려줍니다.
// trustedHops가 1 이상이고 X-Forwarded-For가 그만큼의 값을 가지면, 오른쪽에서 trustedHops번째 값입니다
// (오른쪽 값은 우리 쪽 프록시가 붙인 것이라 클라이언트가 위조한 앞쪽 값보다 믿을 수 있습니다).
// 헤더가 없거나 trustedHops보다 짧거나 그 값이 IP가 아니면 RemoteAddr의 호스트입니다.
func ClientIP(r *http.Request, trustedHops int) string {
	if trustedHops > 0 {
		// 헤더가 여러 줄로 오면 한 줄로 이은 것과 같게 다룹니다.
		parts := strings.Split(strings.Join(r.Header.Values("X-Forwarded-For"), ","), ",")
		if len(parts) >= trustedHops {
			if addr, err := netip.ParseAddr(strings.TrimSpace(parts[len(parts)-trustedHops])); err == nil {
				return addr.Unmap().String()
			}
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
