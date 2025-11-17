# user_import_script_normal_mixed

```
// 普通 script 中的复杂用户导入
import { ref, computed, watch, nextTick } from 'vue'
import { useQuasar } from 'quasar'
import { useI18n } from 'vue-i18n'
import { dayjs } from 'dayjs'
import { utc } from 'dayjs/plugin/utc'
import { timezone } from 'dayjs/plugin/timezone'
import { Chart, registerables } from 'chart.js'
import { generateReport } from '@/utils/report'
import { exportToPDF } from '@/utils/export'
import type { ReportData, ChartConfig } from '@/types/report'

// 注册 Day.js 插件
dayjs.extend(utc)
dayjs.extend(timezone)

// 注册 Chart.js
Chart.register(...registerables)

export default {
  name: 'ReportDashboard',
  props: {
    reportId: {
      type: String,
      required: true
    },
    dateRange: {
      type: Object,
      default: () => ({
        start: dayjs().subtract(30, 'day').format('YYYY-MM-DD'),
        end: dayjs().format('YYYY-MM-DD')
      })
    }
  },
  setup(props) {
    const $q = useQuasar()
    const { t, locale } = useI18n()

    const reportData = ref<ReportData | null>(null)
    const chartInstance = ref<Chart | null>(null)
    const isGenerating = ref(false)

    const formattedDateRange = computed(() => {
      const start = dayjs(props.dateRange.start).locale(locale.value)
      const end = dayjs(props.dateRange.end).locale(locale.value)
      return `${start.format('LL')} - ${end.format('LL')}`
    })

    const chartConfig = computed<ChartConfig>(() => ({
      type: 'line',
      data: reportData.value?.chartData || {},
      options: {
        responsive: true,
        plugins: {
          title: {
            display: true,
            text: t('reports.chart.title')
          }
        }
      }
    }))

    async function generateReportData() {
      isGenerating.value = true
      try {
        reportData.value = await generateReport(props.reportId, props.dateRange)
        await nextTick()
        renderChart()
      } catch (error) {
        $q.notify({
          type: 'negative',
          message: t('reports.error.generationFailed')
        })
      } finally {
        isGenerating.value = false
      }
    }

    function renderChart() {
      const ctx = document.getElementById('report-chart') as HTMLCanvasElement
      if (ctx) {
        chartInstance.value = new Chart(ctx, chartConfig.value)
      }
    }

    async function exportReport() {
      if (!reportData.value) return

      try {
        await exportToPDF(reportData.value, {
          title: t('reports.export.title'),
          dateRange: formattedDateRange.value
        })
        $q.notify({
          type: 'positive',
          message: t('reports.export.success')
        })
      } catch (error) {
        $q.notify({
          type: 'negative',
          message: t('reports.export.failed')
        })
      }
    }

    watch(() => props.reportId, () => {
      generateReportData()
    }, { immediate: true })

    return {
      reportData,
      isGenerating,
      formattedDateRange,
      chartConfig,
      generateReportData,
      exportReport
    }
  }
}
```
