type MockFn = {
  (...args: any[]): any;
  mock: {
    calls: any[][];
    implementations: any[];
  };
  mockImplementation: (fn: (...args: any[]) => any) => MockFn;
  mockReturnValue: (value: any) => MockFn;
};

const createMockFunction = (): MockFn => {
  const fn = ((...args: any[]) => {
    fn.mock.calls.push(args);
    const impl = fn.mock.implementations[fn.mock.implementations.length - 1];
    return impl ? impl(...args) : undefined;
  }) as MockFn;

  fn.mock = { calls: [], implementations: [] };
  
  fn.mockImplementation = (impl: (...args: any[]) => any) => {
    fn.mock.implementations.push(impl);
    return fn;
  };
  
  fn.mockReturnValue = (val: any) => {
    fn.mockImplementation(() => val);
    return fn;
  };
  
  return fn;
};

const AsyncStorage = {
  getItem: createMockFunction(),
  setItem: createMockFunction(),
  removeItem: createMockFunction(),
  mergeItem: createMockFunction(),
  clear: createMockFunction(),
  getAllKeys: createMockFunction(),
  multiGet: createMockFunction(),
  multiSet: createMockFunction(),
  multiRemove: createMockFunction(),
  multiMerge: createMockFunction(),
};

export default AsyncStorage; 