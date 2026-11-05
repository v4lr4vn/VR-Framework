import { fetchNui } from './fetchNui';
import { convertImage, uploadToFivemanage } from './convertImage';
import type { Badge, PlayerData, Config, NuiReadyData } from './types';

let config: Config;

const $ = (id: string) => document.getElementById(id)!;

const labelMap: Record<string, string> = {
  lang_header: 'header',
  lang_lastname: 'lastname',
  lang_firstname: 'firstname',
  lang_dob: 'dob',
  lang_sex: 'sex',
  lang_nat: 'nat',
  lang_height: 'height',
};

const card = () => $('vr-idcard');
const show = () => card().classList.add('visible');
const hide = () => card().classList.remove('visible');

const applyLocale = (locale: Record<string, string>) => {
  for (const [elementId, key] of Object.entries(labelMap)) {
    const el = $(elementId);
    if (el && locale[key]) el.textContent = locale[key];
  }
};

const getMugshotSrc = (mugShot: string): string => {
  if (!mugShot || mugShot === 'none') return '';
  return mugShot;
};

const setBadge = (badge?: Badge | 'none') => {
  const el = $('badge');
  if (!badge || badge === 'none') {
    el.style.display = 'none';
    return;
  }
  ($('badgeimg') as HTMLImageElement).src = `assets/badges/${badge.img}.png`;
  $('badgegrade').textContent = badge.grade;
  el.style.display = 'flex';
};

const close = () => {
  hide();
  setBadge('none');
};

const open = (data: PlayerData) => {
  const license = config.licenses[data.cardtype];

  const fields: Record<string, string> = {
    lastname: data.lastname,
    name: data.firstname,
    sign: data.lastname,
    dob: data.birthdate,
    sex: data.sex,
    nationality: data.nationality,
    height: data.height ?? '',
    cardtype: license.header,
  };

  for (const [id, value] of Object.entries(fields)) {
    $(id).textContent = value ?? '';
  }
  $('heightrow').style.display = data.height ? '' : 'none';

  const mugshotSrc = getMugshotSrc(data.mugShot);
  const mugshotEl = $('mugshot') as HTMLImageElement;
  mugshotEl.src = mugshotSrc;
  const scale = config.settings.mugshotScale ?? 1;
  mugshotEl.style.transform = `scale(${scale})`;
  ($('smallmugshot') as HTMLImageElement).src = mugshotSrc;
  card().style.backgroundColor = license.background;

  setBadge(data.badge);
  show();
};

const handleConvertAndUpload = async (txd: string) => {
  try {
    if (config.mugshotsUpload === 'database' || config.mugshotsUpload === 'local') {
      const base64 = await convertImage(txd, 'image/webp');
      fetchNui('convertImageSuccess', { base64 });
      return;
    }

    const base64 = await convertImage(txd);

    const presigned = await fetchNui<{ url: string }>('requestPresignedUrl');
    if (!presigned?.url) {
      console.error('No presigned URL');
      return;
    }

    const imageUrl = await uploadToFivemanage(base64, presigned.url);
    if (imageUrl) {
      fetchNui('convertImageSuccess', { url: imageUrl });
    }
  } catch (err) {
    console.error('Convert/upload failed:', err);
  }
};

window.addEventListener('DOMContentLoaded', async () => {
  const data = await fetchNui<NuiReadyData>('jsReady', {});
  if (!data) return;
  config = data.configData;
  applyLocale(data.localeData);
});

window.addEventListener('message', ({ data }: MessageEvent) => {
  if (data.type === 'playerData') {
    if (config) open(data.playerData as PlayerData);
  } else if (data.type === 'close') {
    close();
  } else if (data.type === 'convertImage') {
    handleConvertAndUpload(data.txd as string);
  }
});
