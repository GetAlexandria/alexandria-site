import { BOOK_PARTS, bookChapters, type BookChapter, type ChapterPart } from '../data/bookChapters';

export const chapters = [...bookChapters].sort((a, b) => a.number - b.number);

export const getChapterBySlug = (slug: string): BookChapter | undefined =>
  chapters.find((chapter) => chapter.slug === slug);

export const getFirstPublishedChapter = (): BookChapter | undefined =>
  chapters.find((chapter) => chapter.status === 'published');

export const getPrevNextChapters = (
  slug: string
): {
  prevChapter?: BookChapter;
  nextChapter?: BookChapter;
} => {
  const index = chapters.findIndex((chapter) => chapter.slug === slug);
  if (index === -1) {
    return {};
  }

  return {
    prevChapter: chapters[index - 1],
    nextChapter: chapters[index + 1],
  };
};

export const groupChaptersByPart = (): { part: ChapterPart; chapters: BookChapter[] }[] =>
  BOOK_PARTS.map((part) => ({
    part,
    chapters: chapters.filter((chapter) => chapter.part === part),
  })).filter((group) => group.chapters.length > 0);
