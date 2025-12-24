export interface Session {
  id: number;
  title: string;
  startTime: number;
  endTime: number;
  originalText: string;
  translatedText: string;
  summary: string;
  isStarred: boolean;
}
