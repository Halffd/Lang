import { DatabaseService } from '../DatabaseService';
import { DictionaryInfo, DictionaryEntry, ImportProgress } from '../../types';
import * as FileSystem from 'expo-file-system';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Mock the dependencies
jest.mock('expo-file-system');
jest.mock('@react-native-async-storage/async-storage');
jest.mock('../TokenizerService');

describe('DatabaseService - Dictionary Import', () => {
  let dbService: DatabaseService;
  let mockProgress: jest.Mock;

  beforeEach(() => {
    // Clear all mocks
    jest.clearAllMocks();
    
    // Create a new instance for each test
    dbService = new DatabaseService();
    mockProgress = jest.fn();
  });

  afterEach(async () => {
    // Clean up after each test
    await dbService.close();
  });

  it('should successfully import a dictionary', async () => {
    const dictionaryInfo: DictionaryInfo = {
      name: 'Test Dictionary',
      description: 'A test dictionary',
      version: '1.0.0',
      author: 'Test Author'
    };

    const entries: DictionaryEntry[] = [
      {
        type: 'term',
        expression: '猫',
        reading: 'ねこ',
        definitions: ['cat'],
        tags: ['n', 'common']
      },
      {
        type: 'term',
        expression: '犬',
        reading: 'いぬ',
        definitions: ['dog'],
        tags: ['n', 'common']
      }
    ];

    await dbService.initialize();
    await dbService.importDictionary(dictionaryInfo, entries, mockProgress);

    // Verify progress callback was called
    expect(mockProgress).toHaveBeenCalledWith(expect.objectContaining({
      total: 2,
      processed: 2,
      status: 'complete'
    }));

    // Verify dictionary was added to the list
    const dictionaries = await dbService.listDictionaries();
    expect(dictionaries).toContainEqual(expect.objectContaining({
      title: dictionaryInfo.name,
      enabled: true,
      format: 3,
      revision: dictionaryInfo.version,
      entryCount: 2
    }));
  });

  it('should handle import errors gracefully', async () => {
    const dictionaryInfo: DictionaryInfo = {
      name: 'Invalid Dictionary',
      description: 'A dictionary with invalid entries',
      version: '1.0.0',
      author: 'Test Author'
    };

    const invalidEntries = [
      {
        type: 'term',
        // Missing required fields
        definitions: ['test']
      }
    ] as unknown as DictionaryEntry[];

    await dbService.initialize();
    
    await expect(
      dbService.importDictionary(dictionaryInfo, invalidEntries, mockProgress)
    ).rejects.toThrow();

    // Verify error progress was reported
    expect(mockProgress).toHaveBeenCalledWith(expect.objectContaining({
      status: 'error'
    }));
  });

  it('should import dictionary from JSON file', async () => {
    const jsonContent = JSON.stringify({
      format: 3,
      revision: '1.0.0',
      sequenced: true,
      title: 'JSON Dictionary',
      entries: [
        {
          type: 'term',
          expression: '本',
          reading: 'ほん',
          definitions: ['book'],
          tags: ['n', 'common']
        }
      ]
    });

    await dbService.initialize();
    await dbService.importFromJson(jsonContent, mockProgress);

    // Verify dictionary was imported
    const dictionaries = await dbService.listDictionaries();
    expect(dictionaries).toContainEqual(expect.objectContaining({
      title: 'JSON Dictionary',
      enabled: true,
      format: 3,
      entryCount: 1
    }));
  });

  it('should enable and disable dictionaries', async () => {
    const dictionaryInfo: DictionaryInfo = {
      name: 'Toggle Dictionary',
      description: 'A dictionary to test enabling/disabling',
      version: '1.0.0',
      author: 'Test Author'
    };

    const entries: DictionaryEntry[] = [
      {
        type: 'term',
        expression: '魚',
        reading: 'さかな',
        definitions: ['fish'],
        tags: ['n', 'common']
      }
    ];

    await dbService.initialize();
    await dbService.importDictionary(dictionaryInfo, entries);

    // Disable dictionary
    await dbService.setDictionaryEnabled(dictionaryInfo.name, false);
    let dictionaries = await dbService.listDictionaries();
    expect(dictionaries[0].enabled).toBe(false);

    // Enable dictionary
    await dbService.setDictionaryEnabled(dictionaryInfo.name, true);
    dictionaries = await dbService.listDictionaries();
    expect(dictionaries[0].enabled).toBe(true);
  });

  it('should delete dictionaries', async () => {
    const dictionaryInfo: DictionaryInfo = {
      name: 'Delete Test Dictionary',
      description: 'A dictionary to test deletion',
      version: '1.0.0',
      author: 'Test Author'
    };

    const entries: DictionaryEntry[] = [
      {
        type: 'term',
        expression: '山',
        reading: 'やま',
        definitions: ['mountain'],
        tags: ['n', 'common']
      }
    ];

    await dbService.initialize();
    await dbService.importDictionary(dictionaryInfo, entries);

    // Delete dictionary
    await dbService.deleteDictionary(dictionaryInfo.name);

    // Verify dictionary was deleted
    const dictionaries = await dbService.listDictionaries();
    expect(dictionaries).not.toContainEqual(expect.objectContaining({
      title: dictionaryInfo.name
    }));
  });
}); 