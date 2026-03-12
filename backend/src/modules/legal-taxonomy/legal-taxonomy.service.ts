import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { LegalTaxonomy, LegalTaxonomyDocument } from './schemas/legal-taxonomy.schema';

@Injectable()
export class LegalTaxonomyService {
  constructor(
    @InjectModel(LegalTaxonomy.name)
    private readonly taxonomyModel: Model<LegalTaxonomyDocument>,
  ) {}

  findAll() {
    return this.taxonomyModel.find().sort({ category: 1, code: 1 }).lean();
  }

  async seedDefaults() {
    const exists = await this.taxonomyModel.countDocuments();
    if (exists > 0) {
      return { seeded: false, reason: 'already-exists' };
    }

    const defaults = [
      { category: 'مدني', code: 'CIVIL.CONTRACT', title: 'الالتزامات التعاقدية' },
      { category: 'تجاري', code: 'COMM.COMPANY', title: 'الشركات' },
      { category: 'جنائي', code: 'CRIM.GENERAL', title: 'الجرائم العامة' },
      { category: 'دستوري', code: 'CONST.RIGHTS', title: 'الحقوق الدستورية' },
    ];

    await this.taxonomyModel.insertMany(defaults);
    return { seeded: true, count: defaults.length };
  }
}
