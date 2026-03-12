import { Types } from 'mongoose';

export function toObjectIdOrUndefined(value?: string | null): Types.ObjectId | undefined {
  if (!value) {
    return undefined;
  }

  const raw = value.toString().trim();
  if (!raw) {
    return undefined;
  }

  if (!Types.ObjectId.isValid(raw)) {
    return undefined;
  }

  return new Types.ObjectId(raw);
}
