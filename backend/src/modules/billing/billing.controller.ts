import { Body, Controller, Get, Param, Post, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { BillingService } from './billing.service';
import { CreateInvoiceDto, CreatePaymentDto } from './dto/billing.dto';

@ApiTags('billing')
@ApiBearerAuth()
@Controller('billing')
export class BillingController {
  constructor(private readonly billingService: BillingService) {}

  @Post('invoices')
  createInvoice(@Body() dto: CreateInvoiceDto, @CurrentUser() user: any) {
    return this.billingService.createInvoice(dto, user?.sub);
  }

  @Get('invoices')
  listInvoices(
    @Query() query: PaginationQueryDto,
    @Query('caseId') caseId?: string,
    @Query('clientId') clientId?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    return this.billingService.listInvoices(query, { caseId, clientId, status, search });
  }

  @Get('invoices/:id/export')
  async exportInvoice(
    @Param('id') id: string,
    @Query('format') format: string,
    @CurrentUser() user: any,
    @Res() res: Response,
  ) {
    const file = await this.billingService.exportInvoice(id, format, user?.sub);
    res.setHeader('Content-Type', file.contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${file.filename}"`);
    res.send(file.buffer);
  }

  @Post('payments')
  createPayment(@Body() dto: CreatePaymentDto, @CurrentUser() user: any) {
    return this.billingService.createPayment(dto, user?.sub);
  }

  @Get('payments')
  listPayments(
    @Query() query: PaginationQueryDto,
    @Query('invoiceId') invoiceId?: string,
    @Query('caseId') caseId?: string,
    @Query('fromDate') fromDate?: string,
    @Query('toDate') toDate?: string,
  ) {
    return this.billingService.listPayments(query, { invoiceId, caseId, fromDate, toDate });
  }
}
