export default () => ({
  app: {
    name: process.env.APP_NAME ?? 'LexIQ Iraq',
    version: process.env.APP_VERSION ?? '0.1.0',
    env: process.env.NODE_ENV ?? 'development',
    port: Number(process.env.PORT ?? 4000),
  },
  api: {
    prefix: process.env.API_PREFIX ?? 'api/v1',
  },
  mongodb: {
    uri: process.env.MONGODB_URI ?? 'mongodb://localhost:27017/lexiq_iraq',
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET ?? 'change_me_access_secret',
    refreshSecret: process.env.JWT_REFRESH_SECRET ?? 'change_me_refresh_secret',
    accessTtl: process.env.JWT_ACCESS_TTL ?? '15m',
    refreshTtl: process.env.JWT_REFRESH_TTL ?? '30d',
  },
  redis: {
    url: process.env.REDIS_URL ?? '',
  },
  storage: {
    provider: process.env.STORAGE_PROVIDER ?? 'local',
    bucket: process.env.STORAGE_BUCKET ?? 'lexiq-iraq',
    region: process.env.STORAGE_REGION ?? 'us-east-1',
    endpoint: process.env.STORAGE_ENDPOINT ?? '',
    accessKey: process.env.STORAGE_ACCESS_KEY ?? '',
    secretKey: process.env.STORAGE_SECRET_KEY ?? '',
  },
  ai: {
    embeddingsProvider: process.env.EMBEDDINGS_PROVIDER ?? 'none',
    openaiApiKey: process.env.OPENAI_API_KEY ?? '',
    disclaimer:
      process.env.LEGAL_DISCLAIMER ??
      'مخرجات الذكاء الاصطناعي هي اقتراحات أولية للمراجعة القانونية ولا تُعد استشارة نهائية.',
  },
});
