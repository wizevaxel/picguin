import type { Theme } from "vitepress"
import DefaultTheme from "vitepress/theme"
import "@catppuccin/vitepress/theme/mocha/lavender.css"
import "./vars.css"
import "./fonts.css"
import "./global.css"
import "./home.css"
import FormatGrid from "./components/FormatGrid.vue"

export default {
	extends: DefaultTheme,
	enhanceApp({ app }) {
		app.component("FormatGrid", FormatGrid)
	},
} satisfies Theme
