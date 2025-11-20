# user_import_script_normal_basic

```ts
// 普通 script 中的用户导入
import { formatCurrency } from '@/utils/currency'
import { ProductService } from '@/services/product'
import type { Product, CartItem } from '@/types/commerce'
import { useCart } from '@/composables/useCart'
import { EVENT_BUS } from '@/utils/eventBus'

export default {
  name: 'ProductList',
  components: {
    ProductCard: () => import('@/components/ProductCard.vue')
  },
  setup() {
    const productService = new ProductService()
    const { cart, addToCart } = useCart()
    
    const products = ref<Product[]>([])
    const loading = ref(false)
    
    const totalValue = computed(() => {
      return products.value.reduce((sum, product) => {
        return sum + product.price
      }, 0)
    })
    
    const formattedTotal = computed(() => {
      return formatCurrency(totalValue.value)
    })
    
    async function loadProducts() {
      loading.value = true
      try {
        products.value = await productService.getProducts()
        EVENT_BUS.emit('products-loaded', products.value.length)
      } finally {
        loading.value = false
      }
    }
    
    function handleAddToCart(product: Product) {
      const cartItem: CartItem = {
        id: product.id,
        name: product.name,
        price: product.price,
        quantity: 1
      }
      addToCart(cartItem)
    }
    
    onMounted(() => {
      loadProducts()
    })
    
    return {
      products,
      cart,
      loading,
      formattedTotal,
      handleAddToCart,
      loadProducts
    }
  }
}
```
