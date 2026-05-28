import type { Theme } from "vitepress"
import DefaultTheme from "vitepress/theme"
import { enhanceAppWithTabs } from "vitepress-plugin-tabs/client"
import "@catppuccin/vitepress/theme/mocha/lavender.css"
import "./vars.css"
import "./fonts.css"
import "./global.css"
import "./home.css"
import FormatGrid from "./components/FormatGrid.vue"

export default {
	extends: DefaultTheme,
	enhanceApp({ app }) {
		enhanceAppWithTabs(app)
		app.component("FormatGrid", FormatGrid)
	},
} satisfies Theme
