export interface WorkshopArticle {
  number: string;
  title: string;
  url: string;
  date: string;
}

export const workshopArticles: WorkshopArticle[] = [
  {
    number: 'WS012',
    title: 'How Not to Slop: The Super Weird Way I Write Better With AI Than Without',
    url: 'https://sociotechnica.org/notebook/antagonistic-writing',
    date: '2026-03-17',
  },
  {
    number: 'WS011',
    title: 'The Context Library of Alexandria (Part 2)',
    url: 'https://sociotechnica.org/notebook/context-library-pt2',
    date: '2026-02-09',
  },
  {
    number: 'WS010',
    title: 'What Happens to Your Product Org When Code Compiles Itself?',
    url: 'https://sociotechnica.org/notebook/code-compiles-itself',
    date: '2026-01-23',
  },
];

export const getRecentArticles = (count: number = 3): WorkshopArticle[] =>
  workshopArticles.slice(0, count);
