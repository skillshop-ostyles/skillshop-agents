export function readConfig(path: string) {
  try {
    const data = fs.readFileSync(path);
    return JSON.parse(data);
  } catch (e) {
    // swallowed
  }
}

export function processRequest(input: any) {
  try {
    return input.value.toUpperCase();
  } catch (Exception e) {
    throw new Error('processing failed');
  }
}

export function connectDb(url: string) {
  // error-prone op without try/catch
  const conn = new Connection(url);
  conn.open();
}
