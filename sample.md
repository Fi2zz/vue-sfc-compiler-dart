# defineModel Samples with Modifiers

## Basic defineModel with Modifiers

```vue
<template>
  <input 
    :value="modelValue" 
    @input="$emit('update:modelValue', $event.target.value)"
  />
</template>

<script setup>
const modelValue = defineModel()
const modelModifiers = defineModel('modelModifiers', { default: () => ({}) })
</script>
```

## defineModel with trim modifier

```vue
<template>
  <input 
    :value="title" 
    @input="$emit('update:title', $event.target.value)"
  />
</template>

<script setup>
const title = defineModel('title', {
  set(value) {
    // Apply trim modifier
    if (titleModifiers.trim) {
      return value.trim()
    }
    return value
  }
})
const titleModifiers = defineModel('titleModifiers', { default: () => ({}) })
</script>
```

## defineModel with number modifier

```vue
<template>
  <input 
    :value="count" 
    @input="$emit('update:count', $event.target.value)"
    type="number"
  />
</template>

<script setup>
const count = defineModel('count', {
  type: Number,
  set(value) {
    // Apply number modifier
    if (countModifiers.number) {
      return Number(value) || 0
    }
    return value
  }
})
const countModifiers = defineModel('countModifiers', { default: () => ({}) })
</script>
```

## defineModel with custom modifier

```vue
<template>
  <input 
    :value="text" 
    @input="$emit('update:text', $event.target.value)"
  />
</template>

<script setup>
const text = defineModel('text', {
  set(value) {
    // Apply custom uppercase modifier
    if (textModifiers.uppercase) {
      return value.toUpperCase()
    }
    return value
  }
})
const textModifiers = defineModel('textModifiers', { default: () => ({}) })
</script>
```

## defineModel with multiple modifiers

```vue
<template>
  <input 
    :value="message" 
    @input="$emit('update:message', $event.target.value)"
  />
</template>

<script setup>
const message = defineModel('message', {
  set(value) {
    let result = value
    
    // Apply trim modifier
    if (messageModifiers.trim) {
      result = result.trim()
    }
    
    // Apply uppercase modifier
    if (messageModifiers.uppercase) {
      result = result.toUpperCase()
    }
    
    // Apply custom length limit modifier
    if (messageModifiers.maxLength && result.length > messageModifiers.maxLength) {
      result = result.slice(0, messageModifiers.maxLength)
    }
    
    return result
  }
})
const messageModifiers = defineModel('messageModifiers', { default: () => ({}) })
</script>
```

## defineModel with lazy modifier

```vue
<template>
  <input 
    :value="description" 
    @change="$emit('update:description', $event.target.value)"
  />
</template>

<script setup>
const description = defineModel('description', {
  set(value) {
    return value
  }
})
const descriptionModifiers = defineModel('descriptionModifiers', { default: () => ({}) })
</script>
```

## defineModel with debounce modifier

```vue
<template>
  <input 
    :value="search" 
    @input="handleInput"
  />
</template>

<script setup>
import { ref, watch } from 'vue'

const search = defineModel('search', {
  set(value) {
    return value
  }
})
const searchModifiers = defineModel('searchModifiers', { default: () => ({}) })

let debounceTimer = null

const handleInput = (event) => {
  const value = event.target.value
  
  if (searchModifiers.debounce) {
    clearTimeout(debounceTimer)
    debounceTimer = setTimeout(() => {
      search.value = value
    }, searchModifiers.debounce)
  } else {
    search.value = value
  }
}
</script>
```

## defineModel with required and modifiers

```vue
<template>
  <input 
    :value="username" 
    @input="$emit('update:username', $event.target.value)"
  />
</template>

<script setup>
const username = defineModel('username', {
  required: true,
  set(value) {
    // Apply trim and lowercase modifiers
    let result = value
    if (usernameModifiers.trim) {
      result = result.trim()
    }
    if (usernameModifiers.lowercase) {
      result = result.toLowerCase()
    }
    return result
  }
})
const usernameModifiers = defineModel('usernameModifiers', { default: () => ({}) })
</script>
```

## defineModel with default value and modifiers

```vue
<template>
  <input 
    :value="email" 
    @input="$emit('update:email', $event.target.value)"
    type="email"
  />
</template>

<script setup>
const email = defineModel('email', {
  default: '',
  set(value) {
    let result = value
    
    // Apply trim modifier
    if (emailModifiers.trim) {
      result = result.trim()
    }
    
    // Apply lowercase modifier
    if (emailModifiers.lowercase) {
      result = result.toLowerCase()
    }
    
    return result
  }
})
const emailModifiers = defineModel('emailModifiers', { default: () => ({}) })
</script>
```

## defineModel with validation and modifiers

```vue
<template>
  <input 
    :value="age" 
    @input="$emit('update:age', $event.target.value)"
    type="number"
  />
</template>

<script setup>
const age = defineModel('age', {
  type: Number,
  set(value) {
    let result = value
    
    // Apply number modifier
    if (ageModifiers.number) {
      result = Number(result) || 0
    }
    
    // Apply min/max validation
    if (ageModifiers.min && result < ageModifiers.min) {
      result = ageModifiers.min
    }
    if (ageModifiers.max && result > ageModifiers.max) {
      result = ageModifiers.max
    }
    
    return result
  }
})
const ageModifiers = defineModel('ageModifiers', { default: () => ({}) })
</script>
```

## defineModel with custom transform and modifiers

```vue
<template>
  <input 
    :value="price" 
    @input="$emit('update:price', $event.target.value)"
  />
</template>

<script setup>
const price = defineModel('price', {
  set(value) {
    let result = value
    
    // Remove non-numeric characters
    result = result.replace(/[^\d.]/g, '')
    
    // Apply currency formatting
    if (priceModifiers.currency) {
      result = parseFloat(result).toFixed(2)
    }
    
    // Apply number modifier
    if (priceModifiers.number) {
      result = Number(result) || 0
    }
    
    return result
  }
})
const priceModifiers = defineModel('priceModifiers', { default: () => ({}) })
</script>
```