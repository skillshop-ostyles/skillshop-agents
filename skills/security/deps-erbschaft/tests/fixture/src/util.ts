import { merge } from 'lodash';

export function mergeConfigs(a: object, b: object): object {
  return merge({}, a, b);
}
