export interface Session {
  id: number;
  title: string;
  startTime: number;
  endTime: number;
  originalText: string;
  translatedText: string;
  summary: string;
  isStarred: boolean;
  type?: 'translation' | 'scan'; // 会话类型
  imageUri?: string; // 扫描图片的 URI
}
