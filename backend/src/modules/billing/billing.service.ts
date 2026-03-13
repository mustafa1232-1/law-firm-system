import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { escapeRegex } from 'src/common/utils/regex.util';
import { AuditService } from '../audit/audit.service';
import { CaseFile, CaseDocument } from '../cases/schemas/case.schema';
import { CreateInvoiceDto, CreatePaymentDto } from './dto/billing.dto';
import { Invoice, InvoiceDocument } from './schemas/invoice.schema';
import { Payment, PaymentDocument } from './schemas/payment.schema';

@Injectable()
export class BillingService {
  constructor(
    @InjectModel(Invoice.name) private readonly invoiceModel: Model<InvoiceDocument>,
    @InjectModel(Payment.name) private readonly paymentModel: Model<PaymentDocument>,
    @InjectModel(CaseFile.name) private readonly caseModel: Model<CaseDocument>,
    private readonly auditService: AuditService,
  ) {}

  async createInvoice(dto: CreateInvoiceDto, actorId?: string) {
    const invoice = await this.invoiceModel.create({
      ...dto,
      clientId: new Types.ObjectId(dto.clientId),
      caseId: dto.caseId ? new Types.ObjectId(dto.caseId) : undefined,
      issueDate: new Date(dto.issueDate),
      dueDate: dto.dueDate ? new Date(dto.dueDate) : undefined,
    });

    await this.auditService.record({
      action: 'billing.invoice.create',
      entity: 'invoices',
      entityId: invoice.id,
      actorId,
    });

    return invoice;
  }

  async createPayment(dto: CreatePaymentDto, actorId?: string) {
    const invoice = await this.invoiceModel.findById(dto.invoiceId);
    if (!invoice) {
      throw new NotFoundException('Invoice not found');
    }

    const payment = await this.paymentModel.create({
      ...dto,
      invoiceId: new Types.ObjectId(dto.invoiceId),
      paymentDate: new Date(dto.paymentDate),
    });

    const totalPaidResult = await this.paymentModel.aggregate([
      { $match: { invoiceId: new Types.ObjectId(dto.invoiceId) } },
      { $group: { _id: '$invoiceId', totalPaid: { $sum: '$amount' } } },
    ]);

    const totalPaid = totalPaidResult[0]?.totalPaid ?? 0;
    invoice.status = totalPaid >= invoice.amount ? 'paid' : totalPaid > 0 ? 'partial' : 'unpaid';
    await invoice.save();

    if (invoice.caseId) {
      const caseId = invoice.caseId.toString();
      const caseInvoices = await this.invoiceModel.find({ caseId: new Types.ObjectId(caseId) }).lean();
      const invoiceIds = caseInvoices.map((entry) => entry._id);

      const paidAgg = invoiceIds.length
        ? await this.paymentModel.aggregate([
            { $match: { invoiceId: { $in: invoiceIds } } },
            { $group: { _id: null, totalPaid: { $sum: '$amount' } } },
          ])
        : [];

      const totalBilled = caseInvoices.reduce((sum, inv) => sum + Number(inv.amount ?? 0), 0);
      const casePaidAmount = Number(paidAgg[0]?.totalPaid ?? 0);
      const outstandingAmount = Math.max(totalBilled - casePaidAmount, 0);
      const paymentStatus =
        totalBilled <= 0
          ? 'unpaid'
          : casePaidAmount <= 0
            ? 'unpaid'
            : casePaidAmount >= totalBilled
              ? 'paid'
              : 'partial';

      await this.caseModel.updateOne(
        { _id: new Types.ObjectId(caseId) },
        {
          $set: {
            paidAmount: casePaidAmount,
            outstandingAmount,
            paymentStatus,
          },
        },
      );
    }

    await this.auditService.record({
      action: 'billing.payment.create',
      entity: 'payments',
      entityId: payment.id,
      actorId,
      payload: { invoiceId: dto.invoiceId, amount: dto.amount },
    });

    return payment;
  }

  async exportInvoice(invoiceId: string, format: string, actorId?: string) {
    if (!Types.ObjectId.isValid(invoiceId)) {
      throw new NotFoundException('Invoice not found');
    }

    const invoice = await this.invoiceModel
      .findById(invoiceId)
      .populate('clientId', 'fullName phone email address companyName')
      .populate('caseId', 'caseNumber title')
      .lean();
    if (!invoice) {
      throw new NotFoundException('Invoice not found');
    }

    const payments = await this.paymentModel
      .find({ invoiceId: new Types.ObjectId(invoiceId) })
      .sort({ paymentDate: -1 })
      .lean();
    const totalPaid = payments.reduce((sum, payment) => sum + Number(payment.amount ?? 0), 0);
    const remaining = Math.max(Number(invoice.amount ?? 0) - totalPaid, 0);

    const client = (invoice.clientId as unknown as Record<string, unknown> | undefined) ?? {};
    const caseRef = (invoice.caseId as unknown as Record<string, unknown> | undefined) ?? {};

    const lines = [
      'تقرير الفاتورة - LexIQ Iraq',
      `رقم الفاتورة: ${invoice.invoiceNumber ?? '-'}`,
      `الحالة: ${this.mapInvoiceStatus((invoice.status ?? '').toString())}`,
      `القيمة: ${Number(invoice.amount ?? 0)} ${(invoice.currency ?? 'IQD').toString()}`,
      `المسدد: ${totalPaid} ${(invoice.currency ?? 'IQD').toString()}`,
      `المتبقي: ${remaining} ${(invoice.currency ?? 'IQD').toString()}`,
      `تاريخ الإصدار: ${this.toDateOnly(invoice.issueDate)}`,
      `تاريخ الاستحقاق: ${this.toDateOnly(invoice.dueDate)}`,
      `العميل: ${(client.fullName ?? '-').toString()}`,
      `هاتف العميل: ${(client.phone ?? '-').toString()}`,
      `بريد العميل: ${(client.email ?? '-').toString()}`,
      `القضية: ${(caseRef.caseNumber ?? '-').toString()} ${(caseRef.title ?? '').toString()}`,
      `ملاحظات: ${(invoice.notes ?? '-').toString()}`,
      '',
      'الدفعات المسجلة:',
      ...(payments.length === 0
          ? ['- لا توجد دفعات مسجلة حتى الآن.']
          : payments.map(
              (payment, index) =>
                `${index + 1}) ${Number(payment.amount ?? 0)} ${(invoice.currency ?? 'IQD').toString()} | ${this.toDateOnly(payment.paymentDate)} | ${(payment.method ?? '-').toString()}`,
            )),
      '',
      'تنبيه:',
      'هذا التقرير للاستخدام المهني داخل المكتب، ويجب مراجعته قبل اعتماده المحاسبي النهائي.',
    ];

    const baseName = `invoice-${invoice.invoiceNumber ?? invoiceId}`
      .replaceAll(/[^a-zA-Z0-9_\-]+/g, '-')
      .replaceAll(/-+/g, '-')
      .toLowerCase();
    const normalizedFormat = (format ?? 'word').toLowerCase();

    await this.auditService.record({
      action: 'billing.invoice.export',
      entity: 'invoices',
      entityId: invoiceId,
      actorId,
      payload: { format: normalizedFormat },
    });

    if (normalizedFormat == 'txt') {
      return {
        filename: `${baseName}.txt`,
        contentType: 'text/plain; charset=utf-8',
        buffer: Buffer.from(lines.join('\n'), 'utf8'),
      };
    }

    const html = this.renderWordDocument({
      title: 'تقرير فاتورة',
      subtitle: `${invoice.invoiceNumber ?? '-'} | ${this.mapInvoiceStatus((invoice.status ?? '').toString())}`,
      lines,
    });

    return {
      filename: `${baseName}.doc`,
      contentType: 'application/msword; charset=utf-8',
      buffer: Buffer.from(html, 'utf8'),
    };
  }

  async listInvoices(
    query: PaginationQueryDto,
    filters?: {
      caseId?: string;
      clientId?: string;
      status?: string;
      search?: string;
    },
  ) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const filter: Record<string, unknown> = {};

    if (filters?.caseId && Types.ObjectId.isValid(filters.caseId)) {
      filter.caseId = new Types.ObjectId(filters.caseId);
    }
    if (filters?.clientId && Types.ObjectId.isValid(filters.clientId)) {
      filter.clientId = new Types.ObjectId(filters.clientId);
    }
    if (filters?.status && ['unpaid', 'partial', 'paid'].includes(filters.status)) {
      filter.status = filters.status;
    }
    if ((filters?.search ?? '').trim().length > 0) {
      const safe = escapeRegex((filters?.search ?? '').trim());
      filter.$or = [
        { invoiceNumber: { $regex: safe, $options: 'i' } },
        { notes: { $regex: safe, $options: 'i' } },
      ];
    }

    const [items, total] = await Promise.all([
      this.invoiceModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('clientId', 'fullName companyName')
        .populate('caseId', 'title caseNumber')
        .lean(),
      this.invoiceModel.countDocuments(filter),
    ]);

    const totalsAgg = await this.invoiceModel.aggregate([
      { $match: filter },
      {
        $group: {
          _id: '$status',
          amount: { $sum: '$amount' },
          count: { $sum: 1 },
        },
      },
    ]);

    const totals = {
      unpaid: { count: 0, amount: 0 },
      partial: { count: 0, amount: 0 },
      paid: { count: 0, amount: 0 },
      all: {
        count: total,
        amount: totalsAgg.reduce((sum, entry) => sum + Number(entry.amount ?? 0), 0),
      },
    };
    for (const row of totalsAgg) {
      const key = `${row._id ?? ''}`;
      if (key === 'unpaid' || key === 'partial' || key === 'paid') {
        totals[key] = {
          count: Number(row.count ?? 0),
          amount: Number(row.amount ?? 0),
        };
      }
    }

    return { items, page, limit, total, totals };
  }

  async listPayments(
    query: PaginationQueryDto,
    filters?: {
      invoiceId?: string;
      caseId?: string;
      fromDate?: string;
      toDate?: string;
    },
  ) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const filter: Record<string, unknown> = {};

    if (filters?.invoiceId && Types.ObjectId.isValid(filters.invoiceId)) {
      filter.invoiceId = new Types.ObjectId(filters.invoiceId);
    }

    if (filters?.caseId && Types.ObjectId.isValid(filters.caseId)) {
      const caseInvoices = await this.invoiceModel
        .find({ caseId: new Types.ObjectId(filters.caseId) })
        .select('_id')
        .lean();
      const invoiceIds = caseInvoices.map((entry) => entry._id);
      if (filter.invoiceId instanceof Types.ObjectId) {
        filter.invoiceId = invoiceIds.some((id) => id.equals(filter.invoiceId as Types.ObjectId))
          ? filter.invoiceId
          : { $in: [new Types.ObjectId()] };
      } else {
        filter.invoiceId = invoiceIds.length
          ? { $in: invoiceIds }
          : { $in: [new Types.ObjectId()] };
      }
    }

    const fromDate = filters?.fromDate ? new Date(filters.fromDate) : null;
    const toDate = filters?.toDate ? new Date(filters.toDate) : null;
    if ((fromDate && !Number.isNaN(fromDate.getTime())) || (toDate && !Number.isNaN(toDate.getTime()))) {
      filter.paymentDate = {
        ...(fromDate && !Number.isNaN(fromDate.getTime()) ? { $gte: fromDate } : {}),
        ...(toDate && !Number.isNaN(toDate.getTime()) ? { $lte: toDate } : {}),
      };
    }

    const [items, total] = await Promise.all([
      this.paymentModel
        .find(filter)
        .sort({ paymentDate: -1 })
        .skip(skip)
        .limit(limit)
        .populate('invoiceId', 'invoiceNumber amount status')
        .lean(),
      this.paymentModel.countDocuments(filter),
    ]);

    const summaryAgg = await this.paymentModel.aggregate([
      { $match: filter },
      {
        $group: {
          _id: null,
          totalAmount: { $sum: '$amount' },
          count: { $sum: 1 },
        },
      },
    ]);

    return {
      items,
      page,
      limit,
      total,
      totals: {
        totalAmount: Number(summaryAgg[0]?.totalAmount ?? 0),
        count: Number(summaryAgg[0]?.count ?? 0),
      },
    };
  }

  private toDateOnly(value: unknown) {
    if (!value) {
      return '-';
    }
    const raw = value instanceof Date ? value.toISOString() : `${value}`;
    return raw.split('T')[0] ?? raw;
  }

  private mapInvoiceStatus(status: string) {
    switch ((status ?? '').toLowerCase()) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'مدفوعة جزئياً';
      case 'overdue':
        return 'متأخرة';
      default:
        return 'غير مدفوعة';
    }
  }

  private renderWordDocument(input: { title: string; subtitle?: string; lines: string[] }) {
    const body = input.lines.map((line) => `<p>${this.escapeHtml(line)}</p>`).join('');
    return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <title>${this.escapeHtml(input.title)}</title>
  <style>
    body { font-family: Tahoma, Arial, sans-serif; direction: rtl; unicode-bidi: embed; line-height: 1.65; padding: 24px; color: #111827; }
    h1 { margin: 0 0 6px; font-size: 24px; }
    h2 { margin: 0 0 18px; font-size: 16px; font-weight: 500; color: #374151; }
    p { margin: 0 0 8px; font-size: 14px; white-space: pre-wrap; }
  </style>
</head>
<body>
  <h1>${this.escapeHtml(input.title)}</h1>
  <h2>${this.escapeHtml(input.subtitle ?? '')}</h2>
  ${body}
</body>
</html>`;
  }

  private escapeHtml(value: string) {
    return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
  }
}
