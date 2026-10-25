import i18n from "i18next"
import { initReactI18next } from "react-i18next"
import LanguageDetector from "i18next-browser-languagedetector"
import en from "./locales/en/common.json"
import ru from "./locales/ru/common.json"

export const SUPPORTED_LANGUAGES = ["en", "ru"] as const

i18n
  .use(initReactI18next)
  .use(LanguageDetector)
  .init({
    resources: { en: { common: en }, ru: { common: ru } },
    supportedLngs: SUPPORTED_LANGUAGES,
    fallbackLng: "en",
    defaultNS: "common",
    detection: {
      order: ["localStorage", "navigator", "htmlTag"],
      caches: ["localStorage"],
    },
    interpolation: { escapeValue: false },
  })

i18n.on("languageChanged", (lng) => document.documentElement.setAttribute("lang", lng))

export default i18n
