import { writable } from "svelte/store";

export const visibility = writable<boolean>(false);
export const browserMode = writable<boolean>(false);
export const resName = writable<string>("");

export const PROPERTIES = writable<any[]>([]);
export const SHELLS = writable<any[]>([]);
export const APARTMENTS = writable<any[]>([]);

export const REALTOR_GRADE = writable<number>(3);

export const TEMP_HIDE = writable<boolean>(false);

interface IConfig {
    manageProperty: number;
    changePropertyForSale: number;
    sellProperty: number;
    listNewProperty: number;
    deleteProperty: number;
    setApartments: number;
}

export const CONFIG = writable<IConfig>({
    manageProperty: 1,
    changePropertyForSale: 0,
    sellProperty: 0,
    listNewProperty: 2,
    deleteProperty: 2,
    setApartments: 2,
});
