import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import {
  ConstitutionArticle,
  ConstitutionArticleDocument,
} from '../constitution/schemas/constitution-article.schema';
import { JudicialDecision, JudicialDecisionDocument } from '../decisions/schemas/judicial-decision.schema';
import { LawArticle, LawArticleDocument } from '../laws/schemas/law-article.schema';
import { AuditService } from '../audit/audit.service';
import {
  CreateResearchFolderDto,
  SaveAuthorityDto,
  SearchResearchDto,
} from './dto/research.dto';
import { ResearchFolder, ResearchFolderDocument } from './schemas/research-folder.schema';
import { SavedAuthority, SavedAuthorityDocument } from './schemas/saved-authority.schema';

@Injectable()
export class ResearchService {
  constructor(
    @InjectModel(ConstitutionArticle.name)
    private readonly constitutionModel: Model<ConstitutionArticleDocument>,
    @InjectModel(LawArticle.name)
    private readonly lawArticleModel: Model<LawArticleDocument>,
    @InjectModel(JudicialDecision.name)
    private readonly decisionModel: Model<JudicialDecisionDocument>,
    @InjectModel(ResearchFolder.name)
    private readonly folderModel: Model<ResearchFolderDocument>,
    @InjectModel(SavedAuthority.name)
    private readonly savedAuthorityModel: Model<SavedAuthorityDocument>,
    private readonly auditService: AuditService,
  ) {}

  async search(dto: SearchResearchDto) {
    const normalized = normalizeArabic(dto.q);

    const [constitution, laws, decisions] = await Promise.all([
      dto.type && dto.type !== 'constitution'
        ? Promise.resolve([])
        : this.constitutionModel
            .find({
              $or: [
                { $text: { $search: dto.q } },
                { normalizedText: { $regex: normalized, $options: 'i' } },
              ],
            })
            .limit(8)
            .lean(),
      dto.type && dto.type !== 'law'
        ? Promise.resolve([])
        : this.lawArticleModel
            .find({
              $or: [
                { $text: { $search: dto.q } },
                { normalizedText: { $regex: normalized, $options: 'i' } },
              ],
            })
            .limit(8)
            .populate('lawId', 'title lawNumber year')
            .lean(),
      dto.type && dto.type !== 'decision'
        ? Promise.resolve([])
        : this.decisionModel
            .find({
              $or: [
                { $text: { $search: dto.q } },
                { normalizedText: { $regex: normalized, $options: 'i' } },
              ],
              ...(dto.court ? { courtName: { $regex: dto.court, $options: 'i' } } : {}),
              ...(dto.legalDomain ? { legalDomain: dto.legalDomain } : {}),
            })
            .limit(8)
            .lean(),
    ]);

    const resultItems = [
      ...constitution.map((item) => ({
        type: 'constitution',
        id: item._id.toString(),
        title: `الدستور العراقي - المادة ${item.articleNumber}`,
        snippet: item.text.slice(0, 220),
        source: 'constitution_articles',
        date: item.updatedAt,
        relevanceReason: 'تطابق مع كلمات/مصطلحات دستورية مرتبطة بالسؤال',
        linkedArticles: item.linkedLawArticleIds,
        linkedDecisions: item.linkedDecisionIds,
      })),
      ...laws.map((item: any) => ({
        type: 'law',
        id: item._id.toString(),
        title: `${item.lawId?.title ?? 'قانون'} - المادة ${item.articleNumber}`,
        snippet: item.text.slice(0, 220),
        source: 'law_articles',
        date: item.updatedAt,
        relevanceReason: 'تطابق مع المادة القانونية ذات الصلة',
        linkedArticles: [item.articleNumber],
        linkedDecisions: [],
      })),
      ...decisions.map((item) => ({
        type: 'decision',
        id: item._id.toString(),
        title: `${item.courtName} - القرار ${item.decisionNumber}`,
        snippet: (item.summary ?? item.fullText ?? '').slice(0, 220),
        source: 'judicial_decisions',
        date: item.decisionDate,
        relevanceReason: 'تطابق مع نمط تسبيب قضائي مشابه',
        linkedArticles: item.legalArticleReferences,
        linkedDecisions: [item._id.toString()],
      })),
    ];

    return {
      query: dto.q,
      total: resultItems.length,
      items: resultItems,
      note: 'النتائج أولية ويجب مراجعتها مهنيًا قبل اعتمادها في المرافعات.',
    };
  }

  async createFolder(dto: CreateResearchFolderDto, userId?: string) {
    const folder = await this.folderModel.create({
      ...dto,
      userId: userId ? new Types.ObjectId(userId) : undefined,
    });
    return folder;
  }

  listFolders(userId?: string) {
    const filter = userId ? { userId: new Types.ObjectId(userId) } : {};
    return this.folderModel.find(filter).sort({ createdAt: -1 }).lean();
  }

  async saveAuthority(folderId: string, dto: SaveAuthorityDto, actorId?: string) {
    const saved = await this.savedAuthorityModel.create({
      ...dto,
      folderId: new Types.ObjectId(folderId),
      caseId: dto.caseId ? new Types.ObjectId(dto.caseId) : undefined,
    });

    await this.auditService.record({
      action: 'research.authority.save',
      entity: 'saved_authorities',
      entityId: saved.id,
      actorId,
      payload: { folderId, authorityType: dto.authorityType },
    });

    return saved;
  }

  listFolderAuthorities(folderId: string) {
    return this.savedAuthorityModel
      .find({ folderId: new Types.ObjectId(folderId) })
      .sort({ createdAt: -1 })
      .lean();
  }
}
