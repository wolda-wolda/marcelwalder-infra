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
const navToggle = document.getElementById("nav-toggle");
const desktopMediaQuery = window.matchMedia("(min-width: 56rem)");

function setNavOpen(open) {
  if (!siteHeader || !navToggle) return;
  siteHeader.classList.toggle("nav-open", open);
  navToggle.setAttribute("aria-expanded", String(open));
}

if (siteHeader && navToggle) {
  navToggle.addEventListener("click", () => {
    const isOpen = navToggle.getAttribute("aria-expanded") === "true";
    setNavOpen(!isOpen);
  });

  document.addEventListener("click", (event) => {
    if (
      navToggle.getAttribute("aria-expanded") === "true" &&
      !siteHeader.contains(event.target)
    ) {
      setNavOpen(false);
    }
  });

  document.addEventListener("keydown", (event) => {
    if (
      event.key === "Escape" &&
      navToggle.getAttribute("aria-expanded") === "true"
    ) {
      setNavOpen(false);
      navToggle.focus();
    }
  });

  desktopMediaQuery.addEventListener("change", (event) => {
    if (event.matches) {
      setNavOpen(false);
    }
  });
}

// Scrollspy aria-current synchronization + IntersectionObserver fallback
const navLinks = Array.from(document.querySelectorAll(".site-nav a"));
const sections = Array.from(document.querySelectorAll("main section[id]"));

for (const link of navLinks) {
  link.addEventListener("click", () => setNavOpen(false));
}

if (CSS.supports("scroll-target-group: auto")) {
  let rafId = 0;
  const syncAriaCurrent = () => {
    rafId = 0;
    const currentLink = document.querySelector(".site-nav a:target-current");
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
