import { defineConfig } from "vitepress"

export default defineConfig({
	title: "Picguin",
	description: "High-performance Luau image codecs",
	base: "/picguin/",
	themeConfig: {
		logo: "logo.svg",
		nav: [
			{ text: "Introduction", link: "/guide/get-started" },
			{ text: "Formats", link: "/formats/png" },
		],

		sidebar: {
			"/guide/": [
				{ text: "Get Started", link: "/guide/get-started" }
			],
			"/formats/": [
				{ text: "PNG", link: "/formats/png" }
			],
		},

		socialLinks: [{ icon: "github", link: "https://github.com/wizevaxel/picguin" }],
		footer: {
			message: "Released under the MIT License.",
			copyright: "Copyright © 2026 wizeväxel",
		},
	},
})
