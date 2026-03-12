import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JobsOptions, Queue } from 'bullmq';

@Injectable()
export class QueueService implements OnModuleDestroy {
  private readonly redisUrl: string;
  private readonly queues = new Map<string, Queue>();

  constructor(private readonly configService: ConfigService) {
    this.redisUrl = this.configService.get<string>('redis.url') ?? '';
  }

  private getQueue(name: string): Queue | null {
    if (!this.redisUrl) {
      return null;
    }
    const existing = this.queues.get(name);
    if (existing) {
      return existing;
    }
    const queue = new Queue(name, {
      connection: { url: this.redisUrl } as any,
    });
    this.queues.set(name, queue);
    return queue;
  }

  async enqueue(
    queueName: string,
    jobName: string,
    payload: unknown,
    options?: JobsOptions,
  ): Promise<{ queued: boolean; jobId?: string }>{
    const queue = this.getQueue(queueName);
    if (!queue) {
      return { queued: false };
    }
    const job = await queue.add(jobName, payload, options);
    return { queued: true, jobId: job.id?.toString() };
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.all(Array.from(this.queues.values()).map((q) => q.close()));
  }
}
