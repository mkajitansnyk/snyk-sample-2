import createApp from './app';

const port = 5000;
const start = async () => {
  const app = await createApp({
    fastifyOpts: {
      logger: {
        level: 'debug',
      },
    },
  });

  try {
    await app.listen(port, '0.0.0.0'); // listen on all available IPv4 interfaces
  } catch (error: unknown) {
    app.log.error(error);
  }
};

start();
