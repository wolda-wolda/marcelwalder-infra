try {
  const savedTheme = localStorage.getItem("color-scheme");
  if (savedTheme === "light" || savedTheme === "dark") {
    document.querySelector('meta[name="color-scheme"]').content = savedTheme;
  }
} catch {
  /* Storage blocked: keep default light dark system preference */
}
