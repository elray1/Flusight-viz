import axios from 'axios';
import target_variables from './assets/target_variables.json';
import locations from './assets/locations.json';
import available_as_ofs from './static/data/available_as_ofs.json';
import models from './static/data/models.json';

export default {
  // Target: https://go.nuxtjs.dev/config-target
  target: 'static',

  // Global page headers: https://go.nuxtjs.dev/config-head
  head: {
    title: 'Visualization - COVID-19 Forecast Hub',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { hid: 'description', name: 'description', content: '' },
      { name: 'format-detection', content: 'telephone=no' }
    ],
    link: [
      { rel: 'icon', type: 'image/x-icon', href: '/favicon.png' }
    ]
  },

  // Global CSS: https://go.nuxtjs.dev/config-css
  css: [
  ],

  // Plugins to run before rendering page: https://go.nuxtjs.dev/config-plugins
  plugins: [
    { src: '@/plugins/vue-plotly', mode: 'client' }
  ],

  // Auto import components: https://go.nuxtjs.dev/config-components
  components: true,

  // Modules for dev and build (recommended): https://go.nuxtjs.dev/config-modules
  buildModules: [
  ],

  // Modules: https://go.nuxtjs.dev/config-modules
  modules: [
    // https://go.nuxtjs.dev/axios
    '@nuxtjs/axios',
    'bootstrap-vue/nuxt',
    ['nuxt-forecast-viz',
      {
        target_variables: target_variables,
        init_target_var: 'hosp',
        locations: locations,
        init_location: 'US',
        intervals: ['0%', '50%', '95%'],
        init_interval: '95%',
        available_as_ofs: available_as_ofs,
        init_as_of_date: available_as_ofs.hosp[available_as_ofs.hosp.length - 1],
        current_date: available_as_ofs.hosp[available_as_ofs.hosp.length - 1],
        models: models,
        default_models: ['Flusight-baseline'],
        all_models: false,
        disclaimer: ''
      }
    ]
  ],

  // Axios module configuration: https://go.nuxtjs.dev/config-axios
  axios: {},

  // Build Configuration: https://go.nuxtjs.dev/config-build
  build: {
    extend: function (config, {isDev, isClient}) {
      config.node = {
        fs: 'empty'
      };
    }
  },

  generate: {
    cache: false
  },

  router: {
    base: '/Flusight-viz/'
  }
}
