import fastify, { FastifyInstance, FastifyServerOptions } from 'fastify';
import { routes } from './routes';

type AppOptions = {
  fastifyOpts?: FastifyServerOptions;
};

export const app = async ({
  fastifyOpts,
}: AppOptions): Promise<FastifyInstance> => {
  const app = fastify(fastifyOpts);
  await Promise.all([
    app.register(routes, { prefix: '/api' }),
  ]);
  return app;
};

export default app;
