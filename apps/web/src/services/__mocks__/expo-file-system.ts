interface MockFunction<T = any> {
  (...args: any[]): T;
  mock: {
    calls: any[][];
    implementations: Array<(...args: any[]) => T>;
  };
  mockImplementation: (fn: (...args: any[]) => T) => MockFunction<T>;
  mockReturnValue: (value: T) => MockFunction<T>;
}

const createMockFunction = <T>(): MockFunction<T> => {
  const fn = ((...args: any[]) => {
    fn.mock.calls.push(args);
    const impl = fn.mock.implementations[fn.mock.implementations.length - 1];
    return impl ? impl(...args) : undefined;
  }) as MockFunction<T>;

  fn.mock = { calls: [], implementations: [] };
  
  fn.mockImplementation = (impl: (...args: any[]) => T) => {
    fn.mock.implementations.push(impl);
    return fn;
  };
  
  fn.mockReturnValue = (val: T) => {
    fn.mockImplementation(() => val);
    return fn;
  };
  
  return fn;
};

const mockFiles: Record<string, string> = {};

export const documentDirectory = '/mock/document/directory/';
export const cacheDirectory = '/mock/cache/directory/';
export const bundleDirectory = '/mock/bundle/directory/';

export const readAsStringAsync = createMockFunction<Promise<string>>()
  .mockImplementation(async () => '');

export const writeAsStringAsync = createMockFunction<Promise<void>>()
  .mockImplementation(async () => {});

export const deleteAsync = createMockFunction<Promise<void>>()
  .mockImplementation(async () => {});

export const getInfoAsync = createMockFunction<Promise<{
  exists: boolean;
  isDirectory: boolean;
  size: number;
  modificationTime: number;
  uri: string;
}>>().mockImplementation(async () => ({
  exists: true,
  isDirectory: false,
  size: 0,
  modificationTime: Date.now(),
  uri: 'file://mock/path'
}));

export const makeDirectoryAsync = createMockFunction<Promise<void>>()
  .mockImplementation(async () => {});

export const moveAsync = createMockFunction<Promise<void>>()
  .mockImplementation(async () => {});

export const copyAsync = createMockFunction<Promise<void>>()
  .mockImplementation(async () => {});

export const readDirectoryAsync = createMockFunction<Promise<string[]>>()
  .mockImplementation(async () => {
    const files = Object.keys(mockFiles)
      .filter(path => path.startsWith('/mock/'))
      .map(path => path.slice('/mock/'.length));
    return files;
  });

export const downloadAsync = createMockFunction<Promise<{
  uri: string;
  status: number;
  headers: Record<string, string>;
}>>().mockImplementation(async () => ({
  uri: 'file://mock/download/path',
  status: 200,
  headers: {}
})); 