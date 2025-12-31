export class ThemeGradient {
  dark: [string, number][] = [];
  light: [string, number][] = [];
}

export class Theme {
  name: string = '';
  primaryColor: string = '';
  secondaryColor: string = '';
  tertiaryColor: string = '';
  backgroundImage: Resource | null = null;
  gradientColors: ThemeGradient = new ThemeGradient();
}

export const THEMES: Theme[] = [
  {
    name: 'Voot Purple',
    primaryColor: '#3c1464',
    secondaryColor: '#803c1464',
    tertiaryColor: '#403c1464',
    backgroundImage: $r('app.media.app_background_pic_voot_purple'),
    gradientColors: {
      dark: [['#e618052d', 0.0], ['#bf2a1243', 1.0]],
      light: [['#5518052d', 0.0], ['#333c1464', 1.0]]
    }
  },
  {
    name: 'Brand Red',
    primaryColor: '#ff671925',
    secondaryColor: '#80671925',
    tertiaryColor: '#40671925',
    backgroundImage: $r('app.media.app_background_pic_brand_red'),
    gradientColors: {
      dark: [['#e6400d0d', 0.0], ['#bf400d0d', 1.0]],
      light: [['#55671925', 0.0], ['#33671925', 1.0]]
    }
  },
  {
    name: 'Brand Blue',
    primaryColor: '#ff042b75',
    secondaryColor: '#80042b75',
    tertiaryColor: '#40042b75',
    backgroundImage: $r('app.media.app_background_pic_brand_blue'),
    gradientColors: {
      dark: [['#e0042b75', 0.0], ['#bf042b75', 1.0]],
      light: [['#55042b75', 0.0], ['#33042b75', 1.0]]
    }
  },
  {
    name: 'Bibi Pink',
    primaryColor: '#ff8c3959',
    secondaryColor: '#808c3959',
    tertiaryColor: '#408c3959',
    backgroundImage: $r('app.media.app_background_pic_bibi_pink'),
    gradientColors: {
      dark: [['#e08c3959', 0.0], ['#bf8c3959', 1.0]],
      light: [['#558c3959', 0.0], ['#338c3959', 1.0]]
    }
  }
];
