export interface Badge {
    img: string;
    grade: string;
}

export interface License {
    header: string;
    background: string;
    prop: string;
    badge?: string;
}

export interface PlayerData {
    cardtype: string;
    lastname: string;
    firstname: string;
    birthdate: string;
    sex: string;
    nationality: string;
    height?: string;
    mugShot: string;
    badge?: Badge | 'none';
}

export interface Settings {
    closeControl?: number;
    autoClose: {
        status: boolean;
        time: number;
    };
    mugshotScale?: number;
}

export interface Config {
    mugshotsUpload: 'database' | 'fivemanage' | 'local';
    settings: Settings;
    licenses: Record<string, License>;
}

export interface NuiReadyData {
    configData: Config;
    localeData: Record<string, string>;
}
