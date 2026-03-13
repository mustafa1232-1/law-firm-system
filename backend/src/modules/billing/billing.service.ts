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
}
