import type { AuthStatusDTO, OverviewDTO, PostDTO, PostLogDTO, ProviderInfo } from "@shared/types";

export type * from "@shared/types";

/**
 * GET /api/providers. `enabled`: new accounts can be connected (false for experimental ones while they are off).
 * `dataDeletionUri`: Meta apps only, the data deletion callback URL to paste in the Meta dashboard.
 */
export type Provider = ProviderInfo & { configured: boolean; redirectUri: string; enabled: boolean; dataDeletionUri?: string };

export type AuthStatus = AuthStatusDTO;

export type Overview = OverviewDTO;

export interface PostWithLogs extends PostDTO {
  logs: PostLogDTO[];
}

export interface AppSettings {
  publicUrl: string;
  publicUrlLocked: boolean;
  timezone: string | null;
  encryptionKeyFromSecret?: boolean;
  /** "Enable experimental integrations" (providers on unofficial APIs). */
  experimentalIntegrations?: boolean;
  /** Days before unused media is removed by the daily cleanup; 0 = keep forever. */
  mediaRetentionDays?: number;
}

export interface PlatformConfig {
  values: Record<string, string>;
  redirectUri: string;
}
