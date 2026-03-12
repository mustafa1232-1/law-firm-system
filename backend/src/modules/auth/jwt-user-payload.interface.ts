export interface JwtUserPayload {
  sub: string;
  email: string;
  roles: string[];
  firmId?: string;
}
