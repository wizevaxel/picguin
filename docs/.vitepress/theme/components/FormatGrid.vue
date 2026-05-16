<script setup lang="ts">
import { withBase } from "vitepress"

const labels = {
	full: "Full Support",
	decode: "Decode Only",
	planned: "Planned",
}

type Format = {
	name: string
	support: keyof typeof labels
}

const href = (format: Format) => withBase(`/guide/${format.name}`)

const formats: Format[] = [
	{ name: "png", support: "decode" },
	{ name: "bmp", support: "planned" },
	{ name: "gif", support: "planned" },
	{ name: "tga", support: "planned" },
]
</script>

<template>
	<div class="format-grid">
		<component
			v-for="format in formats"
			:is="format.support !== 'planned' ? 'a' : 'span'"
			:key="format.name"
			:href="format.support !== 'planned' ? href(format) : undefined"
			class="format-button"
			:class="format.support"
		>
			{{ format.name }}
			<span class="support-badge" :class="format.support">
				{{ labels[format.support] }}
			</span>
		</component>
	</div>
</template>

<style scoped>
.format-grid {
	display: flex;
	flex-wrap: wrap;
	justify-content: center;
	gap: 12px;
	margin-top: 24px;
}

.format-button {
	display: inline-flex;
	align-items: center;
	justify-content: space-between;
	width: 210px;
	padding: 0 24px;
	line-height: 46px;
	font-family: "Red Hat Mono";
	font-size: 17px;
	text-decoration: none;
	text-transform: uppercase;
	white-space: nowrap;
	color: var(--vp-button-alt-text);
	background-color: var(--vp-button-alt-bg);
	border: 1px solid var(--vp-button-alt-border);
	border-radius: 24px;
	transition:
		color 0.25s,
		border-color 0.25s,
		background-color 0.25s;
}

.format-button:active {
	transition:
		color 0.1s,
		border-color 0.1s,
		background-color 0.1s;
}

.format-button:not(.planned):hover {
	border-color: var(--vp-button-alt-hover-border);
	color: var(--vp-button-alt-hover-text);
	background-color: var(--vp-button-alt-hover-bg);
}

.format-button:not(.planned):active {
	border-color: var(--vp-button-alt-active-border);
	color: var(--vp-button-alt-active-text);
	background-color: var(--vp-button-alt-active-bg);
}

.format-button.planned {
	cursor: default;
	opacity: 0.7;
}

.support-badge {
	display: inline-block;
	border-radius: 12px;
	padding: 0 12px;
	line-height: 26px;
	font-family: var(--vp-font-family-base);
	font-size: 13px;
	text-transform: capitalize;
	color: var(--vp-button-alt-text);
	background-color: var(--vp-c-gray-soft);
}

.support-badge.full {
	color: var(--vp-button-brand-text);
	background-color: var(--vp-c-green-2);
}

.dark .support-badge.full {
	color: var(--vp-c-green-2);
	background-color: var(--vp-c-green-soft);
}

.support-badge.decode {
	color: var(--vp-button-brand-text);
	background-color: var(--vp-c-yellow-2);
}

.dark .support-badge.decode {
	color: var(--vp-c-yellow-2);
	background-color: var(--vp-c-yellow-soft);
}
</style>
