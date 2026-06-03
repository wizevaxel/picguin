import { defineConfig } from "vitepress"
import { tabsMarkdownPlugin } from "vitepress-plugin-tabs"

export default defineConfig({
	title: "Picguin",
	description: "High-performance Luau image codecs",
	base: "/picguin/",
	cleanUrls: true,

	head: [
		["link", { rel: "icon", type: "image/svg+xml", href: "/picguin/favicon.svg" }]
	],

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
						{ text: "Decoding", link: "/guide/png/decoding" },
						{ text: "Encoding", link: "/guide/png/encoding" },
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
	},
})
