# Web Project Template

Extends the base project template with web development patterns for modern JavaScript/TypeScript applications.

## Extends
- base-project.md

## Web-Specific Customizations

### CLAUDE.md Additions
```markdown
## 🌐 Web Technology Stack

### Frontend Framework
- **Framework**: {{FRONTEND_FRAMEWORK}} (e.g., React, Vue, Angular, Svelte)
- **Language**: {{LANGUAGE}} (JavaScript/TypeScript)
- **Build Tool**: {{BUILD_TOOL}} (e.g., Vite, Webpack, Parcel)
- **Package Manager**: {{PACKAGE_MANAGER}} (e.g., npm, yarn, pnpm)

### UI/UX Stack
- **Styling**: {{STYLING_SOLUTION}} (e.g., Tailwind CSS, Styled Components, SCSS)
- **Component Library**: {{COMPONENT_LIBRARY}} (e.g., Material-UI, Ant Design, Chakra UI)
- **State Management**: {{STATE_MANAGEMENT}} (e.g., Redux, Zustand, Pinia, NgRx)
- **Routing**: {{ROUTING_SOLUTION}} (e.g., React Router, Vue Router, Angular Router)

### Development Tools
- **Linting**: {{LINTING_TOOLS}} (e.g., ESLint, Prettier, Stylelint)
- **Testing**: {{TESTING_FRAMEWORK}} (e.g., Jest, Vitest, Cypress, Playwright)
- **Type Checking**: {{TYPE_CHECKING}} (e.g., TypeScript, Flow)
- **Dev Server**: {{DEV_SERVER}} (e.g., Vite dev, Webpack dev server)

### Deployment & Hosting
- **Hosting Platform**: {{HOSTING_PLATFORM}} (e.g., Vercel, Netlify, AWS S3)
- **CI/CD**: {{CICD_PLATFORM}} (e.g., GitHub Actions, GitLab CI, Vercel)
- **Domain**: {{DOMAIN_NAME}}
- **CDN**: {{CDN_SOLUTION}} (e.g., Cloudflare, AWS CloudFront)

## 🎨 UI/UX Architecture

### Component Structure
- **{{COMPONENT_CATEGORY_1}}**: {{COMPONENT_DESCRIPTION_1}}
- **{{COMPONENT_CATEGORY_2}}**: {{COMPONENT_DESCRIPTION_2}}
- **{{COMPONENT_CATEGORY_3}}**: {{COMPONENT_DESCRIPTION_3}}

### Design System
- **Color Palette**: {{COLOR_SYSTEM}}
- **Typography**: {{TYPOGRAPHY_SYSTEM}}
- **Spacing**: {{SPACING_SYSTEM}}
- **Breakpoints**: {{RESPONSIVE_BREAKPOINTS}}

### Accessibility
- **WCAG Compliance**: {{WCAG_LEVEL}} (e.g., AA)
- **Screen Reader**: {{SCREEN_READER_SUPPORT}}
- **Keyboard Navigation**: {{KEYBOARD_SUPPORT}}
- **Color Contrast**: {{CONTRAST_RATIO}}

## ⚡ Performance Metrics

### Core Web Vitals
- **Largest Contentful Paint (LCP)**: {{LCP_SCORE}}
- **First Input Delay (FID)**: {{FID_SCORE}}
- **Cumulative Layout Shift (CLS)**: {{CLS_SCORE}}
- **First Contentful Paint (FCP)**: {{FCP_SCORE}}

### Bundle Analysis
```
Initial Bundle Size: {{INITIAL_BUNDLE_SIZE}}KB
Total Bundle Size: {{TOTAL_BUNDLE_SIZE}}KB
Gzip Compression: {{GZIP_RATIO}}%
Lighthouse Score: {{LIGHTHOUSE_SCORE}}/100

Chunk Breakdown:
- Vendor: {{VENDOR_SIZE}}KB ({{VENDOR_PERCENTAGE}}%)
- App: {{APP_SIZE}}KB ({{APP_PERCENTAGE}}%)
- CSS: {{CSS_SIZE}}KB ({{CSS_PERCENTAGE}}%)
```

### Loading Performance
```
Time to Interactive: {{TTI_SCORE}}ms
Speed Index: {{SPEED_INDEX}}ms
Total Blocking Time: {{TBT_SCORE}}ms
Resource Load Time: {{RESOURCE_LOAD_TIME}}ms
```

## 🧪 Quality Metrics

### Test Coverage
```
Unit Tests: {{UNIT_TEST_COUNT}} tests ({{UNIT_COVERAGE}}% coverage)
Integration Tests: {{INTEGRATION_TEST_COUNT}} tests
E2E Tests: {{E2E_TEST_COUNT}} scenarios
Visual Regression: {{VISUAL_TEST_COUNT}} snapshots

Test Results: {{TEST_STATUS}} ✅
Coverage Threshold: {{COVERAGE_THRESHOLD}}% ({{COVERAGE_STATUS}})
```

### Code Quality
```
ESLint Issues: {{ESLINT_ISSUES}}
TypeScript Errors: {{TS_ERRORS}}
Accessibility Issues: {{A11Y_ISSUES}}
Security Vulnerabilities: {{SECURITY_ISSUES}}
```

### Web-Specific Technical Decisions

- **Framework Choice**: {{FRAMEWORK_RATIONALE}}
- **State Management**: {{STATE_RATIONALE}}
- **Styling Approach**: {{STYLING_RATIONALE}}
- **Build Strategy**: {{BUILD_RATIONALE}}
- **Testing Strategy**: {{TESTING_RATIONALE}}
- **Performance Strategy**: {{PERFORMANCE_RATIONALE}}
```

### settings.json
Uses web-permissions.json template with project-specific additions:

```json
{
  "permissions": {
    "allow": [
      "// Inherits from web-permissions.json",
      
      "// Project-specific build commands",
      "Bash(npm run {{SCRIPT_NAME}}:*)",
      "Bash(yarn {{SCRIPT_NAME}}:*)",
      
      "// Project-specific testing",
      "Bash(npm test:*)",
      "Bash(yarn test:*)",
      "Bash({{E2E_TOOL}} run:*)",
      
      "// Project-specific deployment",
      "Bash({{DEPLOYMENT_TOOL}}:*)",
      
      "// Project-specific domains",
      "WebFetch(domain:{{PROJECT_DOMAIN}})",
      "WebFetch(domain:{{API_DOMAIN}})",
      "WebFetch(domain:{{DOCS_DOMAIN}})"
    ]
  }
}
```

## Web Project Structure

```
web-project/
├── .claude/
│   ├── CLAUDE.md
│   ├── settings.json      (Uses web-permissions.json)
│   └── settings.local.json -> settings.json
├── src/
│   ├── components/
│   │   ├── ui/            (Base UI components)
│   │   ├── forms/         (Form components)
│   │   ├── layout/        (Layout components)
│   │   └── features/      (Feature-specific components)
│   ├── pages/             (Route components)
│   ├── hooks/             (Custom hooks)
│   ├── services/          (API services)
│   ├── store/             (State management)
│   ├── utils/             (Utility functions)
│   ├── styles/            (Global styles)
│   ├── types/             (TypeScript types)
│   └── assets/            (Static assets)
├── public/                (Public static files)
├── tests/
│   ├── unit/              (Unit tests)
│   ├── integration/       (Integration tests)
│   ├── e2e/               (End-to-end tests)
│   └── __mocks__/         (Test mocks)
├── docs/
│   ├── development/
│   │   ├── COMPONENT_GUIDE.md
│   │   ├── STATE_MANAGEMENT.md
│   │   └── DEPLOYMENT.md
│   └── user/
│       ├── USER_GUIDE.md
│       └── API_REFERENCE.md
├── .github/
│   └── workflows/         (CI/CD workflows)
├── package.json
├── tsconfig.json
├── vite.config.ts         (or webpack.config.js)
├── tailwind.config.js     (if using Tailwind)
├── .eslintrc.js
├── .prettierrc
└── README.md
```

## Web-Specific Features

### Development Workflow
- **Hot Module Replacement**: Instant development feedback
- **TypeScript**: Type-safe development experience
- **Linting**: Automated code quality enforcement
- **Formatting**: Consistent code style with Prettier
- **Git Hooks**: Pre-commit quality checks

### Build Optimization
- **Code Splitting**: Automatic bundle optimization
- **Tree Shaking**: Dead code elimination
- **Asset Optimization**: Image and font optimization
- **Caching**: Optimal caching strategies
- **Progressive Enhancement**: Core functionality first

### Testing Strategy
- **Unit Testing**: Component and utility testing
- **Integration Testing**: Feature workflow testing
- **E2E Testing**: User journey validation
- **Visual Testing**: UI regression prevention
- **Performance Testing**: Core Web Vitals monitoring

### Accessibility Features
- **Semantic HTML**: Proper markup structure
- **ARIA Attributes**: Screen reader support
- **Keyboard Navigation**: Full keyboard accessibility
- **Color Contrast**: WCAG compliant contrast ratios
- **Focus Management**: Proper focus handling

### Performance Optimization
- **Lazy Loading**: Component and route lazy loading
- **Image Optimization**: WebP/AVIF format support
- **CDN Integration**: Global content delivery
- **Service Worker**: Offline functionality
- **Resource Hints**: Preload/prefetch optimization

### Template Variables

Replace these placeholders when using this template:

- `{{FRONTEND_FRAMEWORK}}`: Frontend framework choice
- `{{LANGUAGE}}`: JavaScript or TypeScript
- `{{BUILD_TOOL}}`: Build tool selection
- `{{PACKAGE_MANAGER}}`: Package manager choice
- `{{STYLING_SOLUTION}}`: CSS/styling approach
- `{{COMPONENT_LIBRARY}}`: UI component library
- `{{STATE_MANAGEMENT}}`: State management solution
- `{{ROUTING_SOLUTION}}`: Routing library
- `{{TESTING_FRAMEWORK}}`: Testing framework
- `{{HOSTING_PLATFORM}}`: Deployment platform
- `{{DOMAIN_NAME}}`: Project domain
- Performance metrics (LCP, FID, CLS, etc.)
- Bundle size metrics
- Test coverage statistics
- Technical decision rationales

## Usage Example

Based on modern web application patterns:

```bash
# Use this template for:
# - React/Vue/Angular applications
# - Static site generators
# - Progressive Web Apps (PWAs)
# - E-commerce platforms
# - Content management systems
# - Dashboard applications
```