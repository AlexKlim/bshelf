import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { BrowserRouter } from "react-router-dom"
import "@design/tokens.css"
import "@design/components/bundle.css"
import "./index.css"
import "./i18n"
import App from "./App"
import { reloadOnce } from "./lib/chunks"

if (import.meta.env.PROD && "serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("/sw.js"))
}

window.addEventListener("vite:preloadError", (event) => {
  if (reloadOnce()) event.preventDefault()
})

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
)
