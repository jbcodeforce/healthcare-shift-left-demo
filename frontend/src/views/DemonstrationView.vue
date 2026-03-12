<script setup>
import { computed } from 'vue'
import { marked } from 'marked'
import { demonstrationMarkdown } from '../content/demonstration.js'

marked.setOptions({
  gfm: true,
  breaks: true,
})

const htmlContent = computed(() => marked.parse(demonstrationMarkdown))
</script>

<template>
  <div class="demonstration-view">
    <article class="markdown-body" v-html="htmlContent"></article>
  </div>
</template>

<style scoped>
.demonstration-view {
  max-width: 720px;
}

.markdown-body {
  font-size: 0.95rem;
  line-height: 1.6;
  color: var(--text);
}

.markdown-body :deep(h1) {
  font-size: 1.75rem;
  margin: 0 0 1rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid var(--border);
  color: var(--text-h);
}

.markdown-body :deep(h2) {
  font-size: 1.25rem;
  margin: 1.5rem 0 0.5rem;
  color: var(--text-h);
}

.markdown-body :deep(h3) {
  font-size: 1.05rem;
  margin: 1rem 0 0.4rem;
  color: var(--text-h);
}

.markdown-body :deep(p) {
  margin: 0 0 0.75rem;
}

.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  margin: 0 0 0.75rem;
  padding-left: 1.5rem;
}

.markdown-body :deep(li) {
  margin: 0.2rem 0;
}

.markdown-body :deep(table) {
  width: 100%;
  border-collapse: collapse;
  margin: 0 0 1rem;
  font-size: 0.9rem;
}

.markdown-body :deep(th),
.markdown-body :deep(td) {
  padding: 0.4rem 0.6rem;
  text-align: left;
  border: 1px solid var(--border);
}

.markdown-body :deep(th) {
  background: var(--code-bg);
  font-weight: 600;
  color: var(--text-h);
}

.markdown-body :deep(code) {
  font-family: var(--mono);
  font-size: 0.88em;
  padding: 0.15em 0.4em;
  background: var(--code-bg);
  border-radius: 4px;
}

.markdown-body :deep(pre) {
  margin: 0 0 1rem;
  padding: 0.75rem 1rem;
  background: var(--code-bg);
  border-radius: 6px;
  overflow-x: auto;
  font-size: 0.85rem;
}

.markdown-body :deep(pre code) {
  padding: 0;
  background: none;
}

.markdown-body :deep(hr) {
  border: none;
  border-top: 1px solid var(--border);
  margin: 1.5rem 0;
}

.markdown-body :deep(img) {
  max-width: 100%;
  height: auto;
  display: block;
  margin: 1rem 0;
  border-radius: 4px;
  border: 1px solid var(--border);
}

.markdown-body :deep(strong) {
  font-weight: 600;
  color: var(--text-h);
}
</style>
