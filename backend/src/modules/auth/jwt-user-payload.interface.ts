export interface JwtUserPayload {
  sub: string;
  email: string;
  phone?: string;
  roles: string[];
  firmId?: string;
}
