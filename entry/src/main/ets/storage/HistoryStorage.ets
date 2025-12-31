import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { Session } from '../model/Session';

export class HistoryStorage {
  private static instance: HistoryStorage;
  private rdbStore: relationalStore.RdbStore | undefined;

  private constructor() {}

  public static getInstance(): HistoryStorage {
    if (!HistoryStorage.instance) {
      HistoryStorage.instance = new HistoryStorage();
    }
    return HistoryStorage.instance;
  }

  public async init(context: common.Context): Promise<void> {
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: 'voot_history.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };

    this.rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
    
    const CREATE_SESSION_TABLE = `CREATE TABLE IF NOT EXISTS session (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      startTime INTEGER,
      endTime INTEGER,
      originalText TEXT,
      translatedText TEXT,
      summary TEXT,
      isStarred INTEGER DEFAULT 0
    )`;
    
    await this.rdbStore.executeSql(CREATE_SESSION_TABLE);
    
    // 迁移：添加 isStarred 列（如果不存在）
    try {
      await this.rdbStore.executeSql('ALTER TABLE session ADD COLUMN isStarred INTEGER DEFAULT 0');
    } catch (e) {
      // 列已存在，忽略错误
    }

    // 迁移：添加 type 和 imageUri 列
    try {
      await this.rdbStore.executeSql('ALTER TABLE session ADD COLUMN type TEXT DEFAULT "translation"');
      await this.rdbStore.executeSql('ALTER TABLE session ADD COLUMN imageUri TEXT DEFAULT ""');
    } catch (e) {
      // 列已存在，忽略错误
    }
  }

  public async createSession(title: string): Promise<number> {
    if (!this.rdbStore) return -1;
    const valueBucket: relationalStore.ValuesBucket = {
      title: title,
      startTime: Date.now(),
      endTime: 0,
      originalText: '',
      translatedText: '',
      summary: '',
      isStarred: 0,
      type: 'translation',
      imageUri: ''
    };
    return await this.rdbStore.insert('session', valueBucket);
  }

  public async createScanSession(title: string, originalText: string, translatedText: string, imageUri: string): Promise<number> {
    if (!this.rdbStore) return -1;
    const valueBucket: relationalStore.ValuesBucket = {
      title: title,
      startTime: Date.now(),
      endTime: Date.now(),
      originalText: originalText,
      translatedText: translatedText,
      summary: '',
      isStarred: 0,
      type: 'scan',
      imageUri: imageUri
    };
    return await this.rdbStore.insert('session', valueBucket);
  }

  public async updateSession(id: number, originalText: string, translatedText: string): Promise<void> {
    if (!this.rdbStore) return;
    const valueBucket: relationalStore.ValuesBucket = {
      originalText: originalText,
      translatedText: translatedText,
      endTime: Date.now()
    };
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('id', id);
    await this.rdbStore.update(valueBucket, predicates);
  }

  public async updateSummary(id: number, summary: string): Promise<void> {
    if (!this.rdbStore) return;
    const valueBucket: relationalStore.ValuesBucket = {
      summary: summary
    };
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('id', id);
    await this.rdbStore.update(valueBucket, predicates);
  }

  public async getSessionById(id: number): Promise<Session | undefined> {
    if (!this.rdbStore) return undefined;
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('id', id);
    const resultSet = await this.rdbStore.query(predicates);
    if (resultSet.goToNextRow()) {
      const session: Session = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        startTime: resultSet.getLong(resultSet.getColumnIndex('startTime')),
        endTime: resultSet.getLong(resultSet.getColumnIndex('endTime')),
        originalText: resultSet.getString(resultSet.getColumnIndex('originalText')),
        translatedText: resultSet.getString(resultSet.getColumnIndex('translatedText')),
        summary: resultSet.getString(resultSet.getColumnIndex('summary')),
        isStarred: resultSet.getLong(resultSet.getColumnIndex('isStarred')) === 1,
        type: resultSet.getString(resultSet.getColumnIndex('type')) as 'translation' | 'scan' || 'translation',
        imageUri: resultSet.getString(resultSet.getColumnIndex('imageUri')) || ''
      };
      resultSet.close();
      return session;
    }
    resultSet.close();
    return undefined;
  }

  public async getSessions(type: 'translation' | 'scan' = 'translation'): Promise<Session[]> {
    if (!this.rdbStore) return [];
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('isStarred', 0); // 只获取未收藏的记录
    predicates.equalTo('type', type);
    predicates.orderByDesc('startTime');
    const resultSet = await this.rdbStore.query(predicates);
    const sessions: Session[] = [];
    while (resultSet.goToNextRow()) {
      sessions.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        startTime: resultSet.getLong(resultSet.getColumnIndex('startTime')),
        endTime: resultSet.getLong(resultSet.getColumnIndex('endTime')),
        originalText: resultSet.getString(resultSet.getColumnIndex('originalText')),
        translatedText: resultSet.getString(resultSet.getColumnIndex('translatedText')),
        summary: resultSet.getString(resultSet.getColumnIndex('summary')),
        isStarred: false,
        type: resultSet.getString(resultSet.getColumnIndex('type')) as 'translation' | 'scan' || 'translation',
        imageUri: resultSet.getString(resultSet.getColumnIndex('imageUri')) || ''
      });
    }
    resultSet.close();
    return sessions;
  }

  public async deleteSession(id: number): Promise<void> {
    if (!this.rdbStore) return;
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('id', id);
    await this.rdbStore.delete(predicates);
  }

  public async deleteAllSessions(): Promise<void> {
    if (!this.rdbStore) return;
    const predicates = new relationalStore.RdbPredicates('session');
    await this.rdbStore.delete(predicates);
  }

  public async deleteAllNonStarredSessions(type: 'translation' | 'scan' = 'translation'): Promise<void> {
    if (!this.rdbStore) return;
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('isStarred', 0);
    predicates.equalTo('type', type);
    await this.rdbStore.delete(predicates);
  }

  public async deleteAllStarredSessions(type: 'translation' | 'scan' = 'translation'): Promise<void> {
    if (!this.rdbStore) return;
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('isStarred', 1);
    predicates.equalTo('type', type);
    await this.rdbStore.delete(predicates);
  }

  public async updateStarred(id: number, isStarred: boolean): Promise<void> {
    if (!this.rdbStore) return;
    const valueBucket: relationalStore.ValuesBucket = {
      isStarred: isStarred ? 1 : 0
    };
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('id', id);
    await this.rdbStore.update(valueBucket, predicates);
  }

  public async getStarredSessions(type: 'translation' | 'scan' = 'translation'): Promise<Session[]> {
    if (!this.rdbStore) return [];
    const predicates = new relationalStore.RdbPredicates('session');
    predicates.equalTo('isStarred', 1);
    predicates.equalTo('type', type);
    predicates.orderByDesc('startTime');
    const resultSet = await this.rdbStore.query(predicates);
    const sessions: Session[] = [];
    while (resultSet.goToNextRow()) {
      sessions.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        startTime: resultSet.getLong(resultSet.getColumnIndex('startTime')),
        endTime: resultSet.getLong(resultSet.getColumnIndex('endTime')),
        originalText: resultSet.getString(resultSet.getColumnIndex('originalText')),
        translatedText: resultSet.getString(resultSet.getColumnIndex('translatedText')),
        summary: resultSet.getString(resultSet.getColumnIndex('summary')),
        isStarred: true,
        type: resultSet.getString(resultSet.getColumnIndex('type')) as 'translation' | 'scan' || 'translation',
        imageUri: resultSet.getString(resultSet.getColumnIndex('imageUri')) || ''
      });
    }
    resultSet.close();
    return sessions;
  }
}
