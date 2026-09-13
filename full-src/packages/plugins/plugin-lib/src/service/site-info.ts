export type SiteInfo = {
  siteUrl: string;
};

export interface ISiteInfoGetter {
  getSiteInfo(): Promise<SiteInfo>;
}
