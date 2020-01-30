module.exports = {
  "extends": [
   "eslint:recommended",
   "plugin:react/recommended"
  ],
  "parser": "babel-eslint",
  "env": {
    "browser": true,
  },
  "globals": {
    "$": true,
    "I18n": true,
    "ReactRailsUJS": true,
    "Turbolinks": true,
    "require": true
  },
  "plugins": [
    "babel",
    "react"
  ],
  "settings": {
    "react": {
      "version": "detect"
    }
  },
  "rules": {
    //  TODO Consider to use this rule in future
    // "semi": ["off", "never"],
    "quotes": "off",
    "comma-dangle": "off",
    "class-methods-use-this": "off",
    "import/no-unresolved": "off",
    "import/order": "off",
    "arrow-body-style": "off",
    "default-case": "off",
    "new-cap": "off",
    "brace-style": "off",
    "prefer-arrow-callback": "off",
    "consistent-return": "off",
    "object-curly-newline": "off",
    "arrow-parens": "off",
    "prefer-destructuring": "off",
    "lines-between-class-members": "off",

    "no-shadow": "off",
    "no-plusplus": "off",
    "no-class-assign": "off",
    "no-else-return" : "off",
    "no-unneeded-ternary": "off",
    "no-underscore-dangle": "off",
    "no-use-before-define": "off",
    "no-unused-expressions": "off",

    "max-classes-per-file": "off",

    "react/forbid-prop-types": "off",
    "react/sort-comp": "off",
    "react/no-array-index-key": "off",
    "react/button-has-type": "off",
    "react/destructuring-assignment": "off",
    "react/prefer-stateless-function": "off",
    "react/jsx-one-expression-per-line": "off",
    "react/state-in-constructor": "off",

    "jsx-a11y/alt-text": "off",
    "jsx-a11y/click-events-have-key-events": "off",
    "jsx-a11y/no-static-element-interactions": "off",
    "jsx-a11y/no-noninteractive-element-interactions": "off",

    "indent": ["error", 2, {
      "MemberExpression": "off",
      "SwitchCase": 1
    }],

    "no-var": "error",
    "no-mixed-spaces-and-tabs": "error",
    "space-before-blocks": "error",
    "prefer-const": "error",
    "max-nested-callbacks": ["error", 3],
    "max-params": ["error", 4],
    "complexity": ["error", {
      "max": 8
    }],
    "max-len": ["error", {
      "code": 100
    }],
    "newline-per-chained-call": ["error", {
      "ignoreChainWithDepth": 5
    }],
    "no-tabs": "error",
    "no-inline-comments": "error",
    "no-await-in-loop": "error",
    "object-shorthand": "error",
    "no-extend-native": "error",
    "no-param-reassign": "error",
    "no-script-url": "error",
    "no-new-wrappers": "error",
    "no-duplicate-imports": "error",
    "no-useless-constructor": "error",
    "prefer-template": "error",
    "brace-style": "error",
    "block-spacing": "error",
    "key-spacing": ["error", {
      "align": "value"
    }],
    "object-curly-spacing": ["error", "always"],
    "no-magic-numbers": ["error", {
      "ignore": [0]
    }],

    "react/prop-types": "error",
    "react/jsx-no-duplicate-props": "error",
    "react/jsx-no-useless-fragment": "error",
    "react/static-property-placement": "error",
    "react/jsx-pascal-case": "error",
    "react/jsx-no-bind": "error",
    "react/require-default-props": "error",
    "react/jsx-closing-bracket-location": "error",
    "react/jsx-indent": ["error", 2],
    "react/jsx-indent-props": ["error", 2],
    "react/jsx-closing-bracket-location": ["error", "tag-aligned"],

    // TODO enable in new Eslint version
    // "max-lines-per-function": ["error", {
    //   "max": 35,
    //   "skipComments": true
    // }],
    // TODO enable after setup of I18n with webpack javascript
    //"react/jsx-no-literals": ["error", {
    // "noStrings": true
    //}],
    // TODO enable in new eslint version
    // "no-dupe-else-if": "error",
    // TODO enable in new eslint version
    // "no-import-assign": "error",
    // TODO enable after eslint update
    // "camelcase": ["error", {
    //   "properties": "never",
    //   "ignoreDestructuring": true
    // }],

    // TODO enable in new version of eslint
    // "jsx-a11y/label-has-associated-control": "warn",

    "react/jsx-props-no-spreading": ["error", {
      "html": "enforce",
      "custom": "ignore"
    }],
    "react/jsx-tag-spacing": ["error", {
      "beforeSelfClosing": "always"
    }],
    "react/jsx-max-props-per-line": ["error", {
      "maximum": 2,
      "when": "always"
    }],
    "react/jsx-no-target-blank": ["error", {
      "enforceDynamicLinks":
      "always"
    }],
    "react/jsx-filename-extension": ["error", {
      "extensions": [".js"]
    }]
  }
}

