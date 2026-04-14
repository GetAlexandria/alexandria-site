import { defineConfig } from 'astro/config';
import react from '@astrojs/react';

// Custom rehype plugin to rename "Footnotes" to "References"
function rehypeRenameFootnotes() {
  return (tree) => {
    const visit = (node) => {
      if (node.type === 'element' && node.tagName === 'h2') {
        if (node.properties?.id === 'footnote-label') {
          node.children = [{ type: 'text', value: 'References' }];
        }
      }
      if (node.children) {
        node.children.forEach(visit);
      }
    };
    visit(tree);
  };
}

// https://astro.build/config
export default defineConfig({
  site: 'https://getalexandria.ai',
  integrations: [react()],
  output: 'static',
  build: {
    format: 'file',
  },
  markdown: {
    rehypePlugins: [rehypeRenameFootnotes],
  },
});
