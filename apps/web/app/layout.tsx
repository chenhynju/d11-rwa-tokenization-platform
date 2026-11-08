import type { ReactNode } from 'react';
export const metadata = {title: 'RWA Audit Console'};
export default function Layout({children}: {children: ReactNode}) {
  return <html lang="en"><body style={{margin:0,fontFamily:'system-ui',background:'#101820',color:'#e6edf2'}}>{children}</body></html>;
}
