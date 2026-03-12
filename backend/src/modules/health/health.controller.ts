import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { Public } from 'src/common/decorators/public.decorator';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly configService: ConfigService) {}

  @Get()
  @Public()
  check() {
    return {
      status: 'ok',
      service: this.configService.get<string>('app.name'),
      version: this.configService.get<string>('app.version'),
      env: this.configService.get<string>('app.env'),
      timestamp: new Date().toISOString(),
    };
  }
}
