"use client";

import { useEffect, useState } from "react";

type ThemeName = "dark" | "light";

const THEME_KEY = "shadowmarket-theme";

const setTheme = (value: ThemeName): void => {
  document.documentElement.setAttribute("data-theme", value);
  window.localStorage.setItem(THEME_KEY, value);
};

export function ThemeToggle(): JSX.Element {
  const [theme, setThemeState] = useState<ThemeName>("dark");

  useEffect(() => {
    const storedTheme = window.localStorage.getItem(THEME_KEY);
    if (storedTheme === "light" || storedTheme === "dark") {
      setThemeState(storedTheme);
      setTheme(storedTheme);
      return;
    }
    setTheme("dark");
  }, []);

  const toggleTheme = (): void => {
    const nextTheme: ThemeName = theme === "dark" ? "light" : "dark";
    setThemeState(nextTheme);
    setTheme(nextTheme);
  };

  return (
    <button
      type="button"
      className="theme-toggle"
      onClick={toggleTheme}
      aria-label="Toggle theme"
      title="Toggle theme"
    >
      <span>{theme === "dark" ? "Dark" : "Light"}</span>
      <span className={`theme-knob ${theme}`} />
    </button>
  );
}
