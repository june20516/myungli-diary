// WB1 랜딩 시안 공통 스크립트(#1330).
// 주소 해시 하나로 시안 상태를 고릅니다. 예: #en-live-dark-slots
//   언어 ko | en | ja, 스토어 soon(출시 전, 기본) | live(출시 뒤), 테마 light | dark, slots(슬롯 id 표시)
// 실제 사이트는 언어를 경로(/ko/, /en/, /ja/)로, 다크를 prefers-color-scheme으로 고릅니다.
// 시안은 비교 페이지가 틀마다 상태를 바꿔야 해서 해시로 대신합니다.
{
  const LANGS = ["ko", "en", "ja"];
  const LANG_NAMES = { ko: "한국어", en: "English", ja: "日本語" };
  const SERVER = "https://api.myungli-diary.app"; // 실제 주소는 지휘 대장(설정 파일 한 곳)에서
  const FOOTER_PATHS = {
    "web-landing.footer.terms": "/legal/terms",
    "web-landing.footer.privacy": "/legal/privacy",
    "web-landing.footer.support": "/support",
  };

  const readState = () => {
    const parts = location.hash.replace("#", "").split("-");
    return {
      lang: LANGS.find((lang) => parts.includes(lang)) || "ko",
      live: parts.includes("live"),
      dark: parts.includes("dark")
        || (!parts.includes("light") && matchMedia("(prefers-color-scheme: dark)").matches),
      slots: parts.includes("slots"),
    };
  };

  const writeHash = (state) => {
    const parts = [state.lang, state.live ? "live" : "soon", state.dark ? "dark" : "light"];
    if (state.slots) parts.push("slots");
    location.hash = parts.join("-");
  };

  // tokens.css의 다크 미디어 규칙을 .dark 클래스 규칙으로 바꿔, 시안에서 테마를 직접 고릅니다.
  const moveDarkRuleToClass = () => {
    for (const sheet of document.styleSheets) {
      let rules;
      try { rules = sheet.cssRules; } catch { continue; }
      for (let i = rules.length - 1; i >= 0; i--) {
        const rule = rules[i];
        if (rule.media && rule.media.mediaText.includes("prefers-color-scheme: dark")) {
          const body = [...rule.cssRules].map((inner) => inner.style.cssText).join("");
          sheet.deleteRule(i);
          sheet.insertRule(`:root.dark { ${body} }`, rules.length);
        }
      }
    }
  };

  const setText = (element, text) => {
    element.textContent = "";
    text.split("\n").forEach((line, index) => {
      if (index > 0) element.append(document.createElement("br"));
      element.append(line);
    });
  };

  const render = () => {
    const state = readState();
    const copy = window.LANDING_COPY[state.lang];
    const root = document.documentElement;
    root.lang = state.lang;
    root.classList.toggle("dark", state.dark);
    root.classList.toggle("show-slots", state.slots);
    root.dataset.store = state.live ? "live" : "soon";
    document.title = copy["web-landing.meta.title"];

    for (const element of document.querySelectorAll("[data-slot]")) {
      const slot = element.dataset.slot;
      const scene = element.dataset.scene;
      const value = scene ? copy[slot][scene] : copy[slot];
      if (element.tagName === "IMG") {
        element.alt = value;
      } else if (element.hasAttribute("aria-label")) {
        element.setAttribute("aria-label", value);
      } else {
        setText(element, value);
      }
      if (FOOTER_PATHS[slot]) element.href = `${SERVER}${FOOTER_PATHS[slot]}?lang=${state.lang}`;
    }
    for (const image of document.querySelectorAll("img[data-scene]")) {
      image.src = `shots/${state.lang}-${image.dataset.scene}.webp`;
    }
    for (const name of document.querySelectorAll("[data-app-name]")) {
      name.textContent = copy.appName;
    }
    for (const nav of document.querySelectorAll(".lang")) {
      nav.innerHTML = LANGS.map((lang) => `<a href="#${lang}" data-lang="${lang}"${lang === state.lang ? ' aria-current="true"' : ""}>${LANG_NAMES[lang]}</a>`).join("");
    }
    requestAnimationFrame(postHeight);
  };

  const postHeight = () => {
    if (window.parent !== window) {
      window.parent.postMessage({ landingHeight: document.documentElement.scrollHeight, frame: window.name }, "*");
    }
  };

  document.addEventListener("click", (event) => {
    const link = event.target.closest(".lang a");
    if (!link) return;
    event.preventDefault();
    writeHash({ ...readState(), lang: link.dataset.lang });
  });

  moveDarkRuleToClass();
  window.addEventListener("hashchange", render);
  window.addEventListener("load", postHeight);
  new ResizeObserver(postHeight).observe(document.body);
  if (document.fonts) document.fonts.ready.then(postHeight);
  render();
}
