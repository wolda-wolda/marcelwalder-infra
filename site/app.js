const rootMeta = document.querySelector('meta[name="color-scheme"]');
const themeToggle = document.getElementById("theme-toggle");
const printBtn = document.getElementById("print-cv");
const contactDialog = document.getElementById("contact-dialog");
const openModalBtn = document.getElementById("open-contact-modal");
const dialogPrintBtn = document.getElementById("dialog-print-btn");
const legalDialog = document.getElementById("legal-dialog");
const openLegalBtn = document.getElementById("open-legal-modal");

const systemDarkQuery = window.matchMedia("(prefers-color-scheme: dark)");

function getRenderedScheme() {
  const explicit = rootMeta?.getAttribute("content");
  if (explicit === "light" || explicit === "dark") {
    return explicit;
  }
  return systemDarkQuery.matches ? "dark" : "light";
}

function applyScheme(value) {
  if (!rootMeta) return;
  rootMeta.setAttribute("content", value ?? "light dark");
}

if (themeToggle) {
  themeToggle.addEventListener("click", () => {
    const current = getRenderedScheme();
    const target = current === "dark" ? "light" : "dark";
    const systemPref = systemDarkQuery.matches ? "dark" : "light";

    try {
      if (target === systemPref) {
        localStorage.removeItem("color-scheme");
        applyScheme("light dark");
      } else {
        localStorage.setItem("color-scheme", target);
        applyScheme(target);
      }
    } catch {
      applyScheme(target === systemPref ? "light dark" : target);
    }
  });
}

window.addEventListener("storage", (event) => {
  if (event.key === "color-scheme") {
    applyScheme(
      event.newValue === "light" || event.newValue === "dark"
        ? event.newValue
        : "light dark"
    );
  }
});

// Print CV action
printBtn?.addEventListener("click", () => window.print());
dialogPrintBtn?.addEventListener("click", () => {
  contactDialog?.close();
  window.print();
});

// Native modal dialogs (with backdrop click close)
function wireModalDialog(dialog, trigger) {
  if (!dialog || !trigger) return;
  trigger.addEventListener("click", () => {
    dialog.showModal();
  });
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) {
      dialog.close("backdrop");
    }
  });
}

wireModalDialog(contactDialog, openModalBtn);
wireModalDialog(legalDialog, openLegalBtn);

const siteHeader = document.querySelector(".site-header");
const headerInner = document.querySelector(".header-inner");
const navToggle = document.getElementById("nav-toggle");
const siteMenu = document.getElementById("site-menu");
const hasNativePopover = Object.hasOwn(HTMLElement.prototype, "popover");

let collapsedHeaderWidth = 0;

function syncHeaderLayout(force = false) {
  if (!siteHeader || !headerInner || !navToggle || !siteMenu) return;

  const isCurrentlyWide = siteHeader.classList.contains("is-wide");
  if (!force && !isCurrentlyWide && headerInner.clientWidth <= collapsedHeaderWidth) {
    return;
  }

  const wasOpen =
    !isCurrentlyWide &&
    (hasNativePopover
      ? siteMenu.matches(":popover-open")
      : siteMenu.classList.contains("is-open"));

  siteHeader.classList.add("is-measuring");
  siteMenu.removeAttribute("popover");
  siteMenu.classList.remove("is-open");
  siteHeader.classList.add("is-wide");

  const fits = headerInner.scrollWidth <= headerInner.clientWidth;

  if (fits) {
    collapsedHeaderWidth = 0;
    navToggle.setAttribute("aria-expanded", "false");
  } else {
    siteHeader.classList.remove("is-wide");
    collapsedHeaderWidth = headerInner.clientWidth;
    if (hasNativePopover) {
      siteMenu.setAttribute("popover", "auto");
      if (wasOpen) {
        siteMenu.showPopover();
      }
    } else if (wasOpen) {
      siteMenu.classList.add("is-open");
    }
    navToggle.setAttribute("aria-expanded", String(wasOpen));
  }

  requestAnimationFrame(() => siteHeader.classList.remove("is-measuring"));
}

if (siteHeader && headerInner && navToggle && siteMenu) {
  syncHeaderLayout(true);

  if (hasNativePopover) {
    siteMenu.addEventListener("toggle", (event) => {
      if (!siteHeader.classList.contains("is-wide")) {
        navToggle.setAttribute("aria-expanded", String(event.newState === "open"));
      }
    });
  } else {
    navToggle.addEventListener("click", () => {
      const nextOpen = !siteMenu.classList.contains("is-open");
      siteMenu.classList.toggle("is-open", nextOpen);
      navToggle.setAttribute("aria-expanded", String(nextOpen));
    });
  }

  if ("ResizeObserver" in window) {
    let layoutRaf = 0;
    const scheduleLayoutSync = () => {
      if (!layoutRaf) {
        layoutRaf = requestAnimationFrame(() => {
          layoutRaf = 0;
          syncHeaderLayout();
        });
      }
    };
    const layoutObserver = new ResizeObserver(scheduleLayoutSync);
    layoutObserver.observe(headerInner);
    layoutObserver.observe(siteMenu);
  } else {
    window.addEventListener("resize", () => syncHeaderLayout(true));
  }

  document.fonts?.ready.then(() => syncHeaderLayout(true));
}

// Scrollspy aria-current synchronization + IntersectionObserver fallback
const navLinks = Array.from(document.querySelectorAll(".site-menu a"));
const sections = Array.from(document.querySelectorAll("main section[id]"));

for (const link of navLinks) {
  link.addEventListener("click", () => {
    if (!siteHeader || siteHeader.classList.contains("is-wide") || !siteMenu) {
      return;
    }
    if (hasNativePopover && siteMenu.matches(":popover-open")) {
      siteMenu.hidePopover();
    } else if (!hasNativePopover) {
      siteMenu.classList.remove("is-open");
      navToggle?.setAttribute("aria-expanded", "false");
    }
  });
}

if (CSS.supports("scroll-target-group: auto")) {
  let rafId = 0;
  const syncAriaCurrent = () => {
    rafId = 0;
    const currentLink = document.querySelector(".site-menu a:target-current");
    for (const link of navLinks) {
      link.setAttribute("aria-current", link === currentLink ? "true" : "false");
    }
  };
  const scheduleSync = () => {
    if (!rafId) {
      rafId = requestAnimationFrame(syncAriaCurrent);
    }
  };
  syncAriaCurrent();
  document.addEventListener("scroll", scheduleSync, { passive: true });
  document.addEventListener("scrollend", syncAriaCurrent);
} else if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          const id = entry.target.getAttribute("id");
          for (const link of navLinks) {
            const active = link.getAttribute("href") === `#${id}`;
            link.setAttribute("aria-current", active ? "true" : "false");
          }
        }
      }
    },
    { rootMargin: "-30% 0px -60% 0px", threshold: 0 }
  );
  for (const section of sections) {
    observer.observe(section);
  }
}

// Dynamic copyright year
const yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = String(new Date().getFullYear());
}
