import { PartialType } from '@nestjs/swagger';
import { CreateConstitutionArticleDto } from './create-constitution-article.dto';

export class UpdateConstitutionArticleDto extends PartialType(
  CreateConstitutionArticleDto,
) {}
