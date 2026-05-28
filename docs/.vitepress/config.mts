import { defineConfig } from "vitepress"
import { tabsMarkdownPlugin } from "vitepress-plugin-tabs"

export default defineConfig({
	title: "Picguin",
	description: "High-performance Luau image codecs",
	base: "/picguin/",
	cleanUrls: true,

	rewrites: {
		"en/:rest*": ":rest*",
	},

	themeConfig: {
		logo: "/logo.svg",

		nav: [
			{ text: "Guide", link: "/guide/introduction" },
			{ text: "Benchmarks", link: "/benchmarks/png" },
		],
		sidebar: {
			"/guide/": [
				{ text: "Introduction", link: "/guide/introduction" },
				{ text: "Shared Types", link: "/guide/shared" },
				{
					text: "PNG",
					items: [
						{ text: "Overview", link: "/guide/png/" },
						{ text: "Decode", link: "/guide/png/decode" },
						{ text: "Encode", link: "/guide/png/encode" },
						{ text: "Types", link: "/guide/png/types" },
					],
				},
			],
			"/benchmarks/": [
				{ text: "PNG", link: "/benchmarks/png" }
			],
		},

		socialLinks: [
			{ icon: "github", link: "https://github.com/wizevaxel/picguin" },
		],
		footer: {
			message: "Released under the MIT License.",
			copyright: "Copyright © 2026 wizeväxel",
		},
	},

	markdown: {
		config(md) {
			md.use(tabsMarkdownPlugin)
		},
		theme: {
			light: "catppuccin-latte",
			dark: "catppuccin-mocha",
		},
	},
})
