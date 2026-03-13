import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { buildSearchTerms, buildTokenRegexConditions } from 'src/common/utils/search-query.util';
import {
  sanitizeHumanText,
  sanitizeLooseObject,
} from 'src/common/utils/text-sanitizer.util';
import { Court, CourtDocument } from './schemas/court.schema';
import { QueryCourtsDto } from './dto/query-courts.dto';

@Injectable()
export class CourtsService {
  constructor(
    @InjectModel(Court.name)
    private readonly courtModel: Model<CourtDocument>,
  ) {}

  async search(query: QueryCourtsDto) {
    const { page, limit, q, governorate, city } = query;
    const skip = (page - 1) * limit;
    const terms = buildSearchTerms(q);

    const filter: Record<string, unknown> = {};
    if (terms.rawQuery) {
      filter.$or = [
        { name: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { nameAr: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { nameEn: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { governorate: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { city: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { district: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { area: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { addressDescription: { $regex: terms.escapedRawQuery, $options: 'i' } },
        ...buildTokenRegexConditions('name', terms.rawTokens),
        ...buildTokenRegexConditions('nameAr', terms.rawTokens),
        ...buildTokenRegexConditions('nameEn', terms.rawTokens),
      ];
    }
    if (governorate) {
      filter.governorate = {
        $regex: buildSearchTerms(governorate).escapedRawQuery,
        $options: 'i',
      };
    }
    if (city) {
      filter.city = {
        $regex: buildSearchTerms(city).escapedRawQuery,
        $options: 'i',
      };
    }

    const [items, total] = await Promise.all([
      this.courtModel
        .find(filter)
        .sort({ governorate: 1, city: 1, name: 1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.courtModel.countDocuments(filter),
    ]);

    return {
      items: items.map((item) => this.sanitizeCourtDocument(item)),
      total,
      page,
      limit,
    };
  }

  async findOne(id: string) {
    const court = await this.courtModel.findById(id).lean();
    if (!court) {
      throw new NotFoundException('Court not found');
    }
    return this.sanitizeCourtDocument(court);
  }

  private sanitizeCourtDocument(court: Record<string, any>) {
    const nameAr = sanitizeHumanText(court.nameAr);
    const nameEn = sanitizeHumanText(court.nameEn);
    const name =
      sanitizeHumanText(court.name, nameAr ?? nameEn ?? 'محكمة عراقية') ??
      'محكمة عراقية';

    return {
      ...court,
      name,
      nameAr,
      nameEn,
      governorate: sanitizeHumanText(court.governorate),
      city: sanitizeHumanText(court.city),
      district: sanitizeHumanText(court.district),
      area: sanitizeHumanText(court.area),
      addressDescription: sanitizeHumanText(court.addressDescription),
      source: sanitizeHumanText(court.source, 'openstreetmap') ?? 'openstreetmap',
      sourceType: sanitizeHumanText(court.sourceType),
      sourceRef: sanitizeHumanText(court.sourceRef),
      sourceUrl: sanitizeHumanText(court.sourceUrl),
      tags: sanitizeLooseObject(court.tags),
    };
  }
}
