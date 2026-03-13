import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
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

  async listInvoices(query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.invoiceModel
        .find()
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('clientId', 'fullName companyName')
        .populate('caseId', 'title caseNumber')
        .lean(),
      this.invoiceModel.countDocuments(),
    ]);

    return { items, page, limit, total };
  }

  async listPayments(query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.paymentModel
        .find()
        .sort({ paymentDate: -1 })
        .skip(skip)
        .limit(limit)
        .populate('invoiceId', 'invoiceNumber amount status')
        .lean(),
      this.paymentModel.countDocuments(),
    ]);

    return { items, page, limit, total };
  }
}
