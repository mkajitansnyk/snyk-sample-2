/* eslint-disable @typescript-eslint/require-await */
import { FastifyInstance } from "fastify";

export const routes = async (fastify: FastifyInstance): Promise<void> => {
  fastify    
    .get(`/`, (request, reply) => {
      void reply.send({
        name: "sample-api",
      });
    })
    .get(`/healthcheck`, (request, reply) => {
      void reply.send({ status: "online" });
    });
};
