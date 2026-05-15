import { defineConfig } from "vitepress"

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
			{ text: "Introduction", link: "/getting-started" },
			{ text: "Formats", link: "/formats/" },
			{ text: "Benchmarks", link: "/benchmarks" },
		],
		sidebar: {
			"/formats/": [
				{ text: "Formats: Overview", link: "/formats/" },
				{
					text: "PNG",
					items: [
						{ text: "Overview", link: "/formats/png/" },
						{ text: "Decode", link: "/formats/png/decode" },
						{ text: "Encode", link: "/formats/png/encode" },
						{ text: "Types", link: "/formats/png/types" },
					],
				},
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
		theme: {
			light: "catppuccin-latte",
			dark: "catppuccin-mocha",
		},
	},
})
