export type ChapterStatus = 'published' | 'coming_soon';
export type ChapterPart = 'The Overload' | 'The Pattern' | 'The Design' | 'The Turn';

export interface BookChapter {
  number: number;
  slug: string;
  title: string;
  part: ChapterPart;
  status: ChapterStatus;
  teaser: string;
  publish_date?: string;
  estimated_read_time?: string;
}

export const BOOK_PARTS: ChapterPart[] = ['The Overload', 'The Pattern', 'The Design', 'The Turn'];

export const bookChapters: BookChapter[] = [
  {
    number: 1,
    slug: 'chapter-1',
    title: 'The Brightest People Break First',
    part: 'The Overload',
    status: 'coming_soon',
    teaser:
      'You unlocked unlimited work. Your best people are breaking — not because the work is too hard, but because there is no structure for work that never ends.',
  },
  {
    number: 2,
    slug: 'chapter-2',
    title: 'The Continuous-Flow Trap',
    part: 'The Overload',
    status: 'coming_soon',
    teaser:
      'The operating model that worked for finite work fails catastrophically when applied to infinite generative capacity. The canyon has no far wall.',
  },
  {
    number: 3,
    slug: 'chapter-3',
    title: "The Gamer's Secret",
    part: 'The Pattern',
    status: 'coming_soon',
    teaser:
      "Every game designer in history solved the problem of infinite possibility the same way: turns. What Richard Garfield and Mark Rosewater knew that your org chart doesn't.",
  },
  {
    number: 4,
    slug: 'chapter-4',
    title: "The Watch Commander's Rhythm",
    part: 'The Pattern',
    status: 'coming_soon',
    teaser:
      'Naval watches work because authority transfer is designed, not improvised. Less coordination time, higher quality coordination.',
  },
  {
    number: 5,
    slug: 'chapter-5',
    title: "The Factory Floor's Lesson",
    part: 'The Pattern',
    status: 'coming_soon',
    teaser:
      'Goldratt proved that pushing work through a system faster than it can absorb creates waste, not speed. Pull beats push.',
  },
  {
    number: 6,
    slug: 'chapter-6',
    title: "The Brain's Veto",
    part: 'The Pattern',
    status: 'coming_soon',
    teaser:
      'Cognitive science explains why your judgment degrades before you notice. The brain vetoes bad decisions by making them invisible.',
  },
  {
    number: 7,
    slug: 'chapter-7',
    title: 'The Anatomy of a Turn',
    part: 'The Design',
    status: 'coming_soon',
    teaser:
      'Comprehension, sync, push, rest. A five-hour cycle designed for human cognitive architecture working alongside AI.',
  },
  {
    number: 8,
    slug: 'chapter-8',
    title: 'The Multiplayer Problem',
    part: 'The Design',
    status: 'coming_soon',
    teaser:
      'Individual turns are necessary but not sufficient. How teams synchronize when everyone is on different rhythms.',
  },
  {
    number: 9,
    slug: 'chapter-9',
    title: 'The Sync Barrier',
    part: 'The Design',
    status: 'coming_soon',
    teaser:
      'The sync barrier replaces continuous overlap. Designed authority transfer means less coordination time, higher quality coordination.',
  },
  {
    number: 10,
    slug: 'chapter-10',
    title: 'Your First Turn',
    part: 'The Turn',
    status: 'coming_soon',
    teaser:
      "The field report. What happened when we redesigned our own team's operating rhythm around seven turns.",
  },
  {
    number: 11,
    slug: 'chapter-11',
    title: 'The Human Advantage',
    part: 'The Turn',
    status: 'coming_soon',
    teaser: 'A week designed for humans working alongside AI — not humans pretending to be AI.',
  },
];
