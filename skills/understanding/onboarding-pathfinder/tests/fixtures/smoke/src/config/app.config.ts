export const appConfig = {
  port: 3000,
  dbUrl: 'postgres://localhost:5432/mydb',
  jwtSecret: 'change-me',
};

export function loadConfig() {
  return { ...appConfig };
}
