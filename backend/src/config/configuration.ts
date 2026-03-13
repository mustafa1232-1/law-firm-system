export default () => ({
  app: {
    name: process.env.APP_NAME ?? 'LexIQ Iraq',
    version: process.env.APP_VERSION ?? '0.1.0',
    env: process.env.NODE_ENV ?? 'development',
    port: Number(process.env.PORT ?? 4000),
  },
  api: {
    prefix: process.env.API_PREFIX ?? 'api',
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
    projectPrefix: process.env.STORAGE_PROJECT_PREFIX ?? '',
    localRoot: process.env.STORAGE_LOCAL_ROOT ?? 'uploads',
    publicBaseUrl: process.env.STORAGE_PUBLIC_BASE_URL ?? '',
  },
  ai: {
    embeddingsProvider: process.env.EMBEDDINGS_PROVIDER ?? 'none',
    openaiApiKey: process.env.OPENAI_API_KEY ?? '',
    openaiBaseUrl: process.env.OPENAI_BASE_URL ?? '',
    openaiOrganization: process.env.OPENAI_ORGANIZATION ?? '',
    openaiProject: process.env.OPENAI_PROJECT ?? '',
    openaiModel: process.env.OPENAI_MODEL ?? 'gpt-4.1-mini',
    openaiEmbeddingModel: process.env.OPENAI_EMBEDDING_MODEL ?? 'text-embedding-3-small',
    disclaimer:
      process.env.LEGAL_DISCLAIMER ??
      'مخرجات الذكاء الاصطناعي هي اقتراحات أولية للمراجعة القانونية وليست استشارة نهائية.',
  },
});
